//
//  RBEditorViewController.swift
//  RBEditorViewController
//
//  Created by cem.olcay on 25/09/2019.
//  Copyright © 2019 cemolcay. All rights reserved.
//

import UIKit

class RBCell: RBGridViewCell {

  public override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    layer.borderColor = UIColor.rhythmCellBorderColor.cgColor
    layer.borderWidth = 1
    layer.backgroundColor = UIColor.rhythmCellBackgroundColor.cgColor
    layer.cornerRadius = 8
    layer.masksToBounds = true
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.borderColor = isSelected ? UIColor.rhythmCellSelectedBorderColor.cgColor : UIColor.rhythmCellBorderColor.cgColor
  }
}

class RBEditorViewController: UIViewController, RBActionViewDelegate, RBGridViewDataSource, RBGridViewDelegate {
  let contentView = UIView(frame: .zero)
  let actionView = RBActionView(frame: .zero)
  let toolbarView = RBToolbarView(frame: .zero)
  let gridView = RBGridView(frame: .zero)
  let actionViewWidth: CGFloat = 100
  let toolbarHeight: CGFloat = 110

  var projectData: RBProjectData! = RBProjectData(name: "Project")
  var history: RBHistory!
  var mode: RBMode = .rhythm
  var selectedRhythmData: RBRhythmData?

  // MARK: Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(contentView)
    contentView.translatesAutoresizingMaskIntoConstraints = false
    contentView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
    contentView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
    contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true

    contentView.addSubview(actionView)
    actionView.translatesAutoresizingMaskIntoConstraints = false
    actionView.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
    actionView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
    actionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
    actionView.widthAnchor.constraint(equalToConstant: actionViewWidth).isActive = true
    actionView.backgroundColor = UIColor.actionBarBackgroundColor
    actionView.delegate = self

    contentView.addSubview(toolbarView)
    toolbarView.translatesAutoresizingMaskIntoConstraints = false
    toolbarView.leftAnchor.constraint(equalTo: actionView.rightAnchor).isActive = true
    toolbarView.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
    toolbarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
    toolbarView.heightAnchor.constraint(equalToConstant: toolbarHeight).isActive = true
    toolbarView.backgroundColor = UIColor.toolbarBackgroundColor
    actionView.selectMode(mode: mode)

    contentView.addSubview(gridView)
    gridView.translatesAutoresizingMaskIntoConstraints = false
    gridView.leftAnchor.constraint(equalTo: actionView.rightAnchor).isActive = true
    gridView.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
    gridView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
    gridView.bottomAnchor.constraint(equalTo: toolbarView.topAnchor).isActive = true
    gridView.backgroundColor = UIColor.gridBackgroundColor
    gridView.playheadView.playheadColor = UIColor.playheadBackgroundColor
    gridView.playheadView.playheadBorderColor = UIColor.playheadBorderColor
    gridView.rangeheadView.playheadColor = UIColor.rangeheadBackgroundColor
    gridView.rangeheadView.playheadBorderColor = UIColor.rangeheadBorderColor
    gridView.measureLineColor = UIColor.measureLineColor
    gridView.measureBackgroundColor = UIColor.measureBackgroundColor
    gridView.measureLabelTextColor = UIColor.measureTextColor
    gridView.playheadView.isUserInteractionEnabled = false
    gridView.rangeheadView.customMenuItems = [
      RBGridViewCellCustomMenuItem(
        title: i18n.snapRangehead.description,
        action: #selector(rangeheadDidPressSnapButton))
    ]

    setup()
  }

  func setup() {
    guard projectData != nil else { return }
    history = RBHistory(dataRef: projectData)
    history.historyDidChangeCallback = {
      DispatchQueue.main.async {
        self.actionView.getActionButton(for: .undo)?.isEnabled = self.history.canUndo
        self.actionView.getActionButton(for: .redo)?.isEnabled = self.history.canRedo
      }
    }

    gridView.rbDelegate = self
    gridView.rbDataSource = self
    gridView.rangeheadView.position = projectData.duration
    projectDataDidChange()
  }

  func reload() {
    guard projectData != nil else { return }
    gridView.reloadData()
    gridView.rangeheadView.position = projectData.duration
  }

  func updateToolbar() {
    switch mode {
    case .strum:
      let toolbarMode = StrumToolbarMode(
        props: StrumToolbarModeProps(
          rhythmData: selectedRhythmData,
          didUpdateStrumCallback: strumToolbar(didUpdate:)))
      toolbarView.render(mode: toolbarMode)
    case .record:
      let toolbarMode = RecordToolbarMode(
        props: RecordToolbarModeProps(
          data: projectData,
          rangeheadPosition: gridView.rangeheadView.position,
          didAddRecordingCallback: recordToolbarDidAddRecording,
          didUpdateRecordingCallback: recordToolbarDidUpdateRecording(duration:),
          didEndRecordingCallback: recordToolbarDidEndRecording))
      toolbarView.render(mode: toolbarMode)
    case .rhythm:
      if selectedRhythmData == nil {
        let toolbarMode = RhythmToolbarMode(
          props: RhythmToolbarModeProps(
            rhythmData: nil,
            didAddRhythmCallback: rhythmToolbar(didAdd:),
            didAddRestCallback: rhythmToolbar(didAdd:),
            didUpdateRhythmCallback: nil))
        toolbarMode.toolbarTitle = i18n.addRhythm.description
        toolbarView.render(mode: toolbarMode)
      } else {
        let toolbarMode = RhythmToolbarMode(
          props: RhythmToolbarModeProps(
            rhythmData: selectedRhythmData,
            didAddRhythmCallback: nil,
            didAddRestCallback: nil,
            didUpdateRhythmCallback: rhythmToolbar(didUpdate:)))
        toolbarMode.toolbarTitle = i18n.editRhythm.description
        toolbarView.render(mode: toolbarMode)
      }
    case .arp:
      let toolbarMode = ArpToolbarMode(
        props: ArpToolbarModeProps(
          rhythmData: selectedRhythmData,
          didUpdateArpCallback: arpToolbar(didUpdate:)))
      toolbarView.render(mode: toolbarMode)
    case .ratchet:
      let toolbarMode = RatchetToolbarMode(
        props: RatchetToolbarModeProps(
          rhythmData: selectedRhythmData,
          didUpdateRatchetCallback: ratchetToolbar(didUpdate:)))
      toolbarView.render(mode: toolbarMode)
    case .velocity:
      let toolbarMode = VelocityToolbarMode(
        props: VelocityToolbarModeProps(
          rhythmData: selectedRhythmData,
          didUpdateVelocityCallback: velocityToolbar(didUpdate:globally:)))
      toolbarView.render(mode: toolbarMode)
    case .transpose:
      let toolbarMode = TransposeToolbarMode(
        props: TransposeToolbarModeProps(
          rhythmData: selectedRhythmData,
          didUpdateTransposeCallback: transposeToolbar(didUpdate:)))
      toolbarView.render(mode: toolbarMode)
    case .snapshots:
      let toolbarMode = SnapshotToolbarMode(
        props: SnapshotToolbarModeProps(
          snapshotData: projectData?.snapshotData ?? RBSnapshotData(),
          didPressAddButtonCallback: snapshotToolbarDidPressAddButton,
          didPressMIDICCButtonCallback: snapshotToolbarDidPressMIDICCButton,
          didSelectSnapshotAtIndex: snapshotToolbarDidSelectSnapshot(at:),
          didDeleteSnapshotAtIndex: snapshotToolbarDidDeleteSnapshot(at:),
          didRequestSnapshotImageAt: snapshotToolbarDidRequestSnapshotImage(at:)))
      toolbarView.render(mode: toolbarMode)
    }
  }

  func projectDataDidChange(shouldReload: Bool = true) {
    // If not quantizing then push history.
    if gridView.isQuantizing == false {
      history.push()
    }
    // Reload if needed.
    if shouldReload {
      reload()
    }
  }

  func didPressClearButton() {}

  // MARK: RBActionViewDelegate

  func actionView(_ actionView: RBActionView, didSelect action: RBAction, sender: UIButton) {
    switch action {
    case .clear:
      selectedRhythmData = nil
      projectData?.rhythm = []
      projectData?.duration = 0
      projectDataDidChange()
      updateToolbar()
    case .quantize:
      let pickerData = PickerData(
        title: i18n.selectQuantizeLevel.description,
        rows: [
          i18n.wholeNote.description,
          i18n.quarterNote.description,
          i18n.sixteenthNote.description
        ],
        initialSelectionIndex: 0,
        cancelCallback: nil,
        doneCallback: { item, index in
          DispatchQueue.main.async {
            self.gridView.quantize(zoomLevel: index)
          }
        })
      presentPicker(data: pickerData)
    case .undo:
      guard let historyItem = history.undo() else { return }
      projectData?.rhythm = historyItem.rhythmData.copy()
      projectData?.duration = historyItem.duration
      reload()
    case .redo:
      guard let historyItem = history.redo() else { return }
      projectData?.rhythm = historyItem.rhythmData.copy()
      projectData?.duration = historyItem.duration
      reload()
    }
  }

  func actionView(_ actionView: RBActionView, didSelect mode: RBMode, sender: UIButton) {
    self.mode = mode
    updateToolbar()
  }

  // MARK: RBScrollViewDataSource

  func numberOfCells(in gridView: RBGridView) -> Int {
    return projectData?.rhythm.count ?? 0
  }

  func rbScrollView(_ gridView: RBGridView, cellAt index: Int) -> RBGridViewCell {
    guard let cellData = projectData?.rhythm[safe: index] else { return RBGridViewCell(frame: .zero) }
    let cell = RBCell(frame: .zero)
    cell.position = cellData.position
    cell.duration = cellData.duration
    return cell
  }

  // MARK: RBScrollViewDelegate

  func gridView(_ gridView: RBGridView, didUpdate cell: RBGridViewCell, at index: Int) {
    projectData?.rhythm[safe: index]?.position = cell.position
    projectData?.rhythm[safe: index]?.duration = cell.duration
  }

  func gridView(_ gridView: RBGridView, didDelete cell: RBGridViewCell, at index: Int) {
    guard projectData?.rhythm.indices.contains(index) == true else { return }
    projectData?.rhythm.remove(at: index)
    projectDataDidChange(shouldReload: !gridView.isQuantizing)
  }

  func gridView(_ gridView: RBGridView, didSelect cell: RBGridViewCell, at index: Int) {
    selectedRhythmData = projectData?.rhythm[safe: index]
    updateToolbar()
  }

  func gridViewDidUnselectCells(_ gridView: RBGridView) {
    selectedRhythmData = nil
    updateToolbar()
  }

  func gridViewDidUpdatePlayhead(_ gridView: RBGridView) {
    return
  }

  func gridViewDidUpdateRangehead(_ gridView: RBGridView, withPanGesture: Bool) {
    projectData?.duration = gridView.rangeheadView.position
    if mode == .record {
      updateToolbar()
    }
  }

  func gridViewDidMoveCell(_ gridView: RBGridView) {
    gridView.snapRangeheadToLastCell()
    projectDataDidChange(shouldReload: false)
  }

  func gridViewDidResizeCell(_ gridView: RBGridView) {
    gridView.snapRangeheadToLastCell()
    projectDataDidChange(shouldReload: false)
  }

  func gridViewDidQuantize(_ gridView: RBGridView) {
    projectDataDidChange()
  }

  // MARK: Rangehead

  @IBAction func rangeheadDidPressSnapButton() {
    let floorPosition = floor(gridView.rangeheadView.position)
    var snapPositions = [Double]()
    var snapPositionTitles = [String]()
    var currentPosition = floorPosition
    var currentBar = Int(floorPosition) + 1
    var currentBeat = 1
    var currentSubbeat = 1
    while currentPosition <= floorPosition + 1.0 {
      // Create title
      var title = "\(currentBar)"
      if currentSubbeat > 1 || currentBeat > 1 {
        title += ".\(currentBeat)"
      }
      if currentSubbeat > 1 {
        title += ".\(currentSubbeat)"
      }
      // Append position-title pair
      snapPositions.append(currentPosition)
      snapPositionTitles.append(title)
      // Increase position
      currentPosition += 1.0/16.0
      currentSubbeat += 1
      // Check if we hit next beat
      if currentSubbeat > 4 {
        currentSubbeat = 1
        currentBeat += 1
      }
      // Check if we hit next bar
      if currentBeat > 4 {
        currentBeat = 1
        currentBar += 1
      }
    }
    // Create picker
    let pickerData = PickerData(
      title: i18n.selectSnapPosition.description,
      rows: snapPositionTitles,
      initialSelectionIndex: 0,
      cancelCallback: nil,
      doneCallback: { item, index in
        guard let safePosition = snapPositions[safe: index] else { return }
        DispatchQueue.main.async {
          self.gridView.rangeheadView.position = safePosition
          self.projectData.duration = safePosition
          self.projectDataDidChange(shouldReload: false)
        }
      })
    presentPicker(data: pickerData)
  }

  // MARK: RhythmToolbarModeView

  func rhythmToolbar(didAdd rhythmData: RBRhythmData) {
    rhythmData.position = gridView.rangeheadView.position
    projectData?.rhythm.append(rhythmData)
    gridView.reloadData()
    gridView.fixOverlaps()
    gridView.snapRangeheadToLastCell()
    projectDataDidChange()
  }

  func rhythmToolbar(didAdd rest: Double) {
    gridView.rangeheadView.position += rest
    projectData?.duration = gridView.rangeheadView.position
    projectDataDidChange()
  }

  func rhythmToolbar(didUpdate rhythmData: RBRhythmData) {
    gridView.reloadData()
    gridView.fixOverlaps()
    gridView.snapRangeheadToLastCell()
    projectDataDidChange()
  }

  // MARK: ArpToolbarModeView

  func arpToolbar(didUpdate arp: RBArp) {
    projectDataDidChange(shouldReload: false)
  }

  // MARK: StrumToolbarModeView

  func strumToolbar(didUpdate strum: RBStrum) {
    projectDataDidChange(shouldReload: false)
  }

  // MARK: VelocityToolbarModeView

  func velocityToolbar(didUpdate velocity: Int, globally: Bool) {
    if globally {
      projectData?.rhythm.forEach({ $0.velocity = velocity })
    }
    projectDataDidChange(shouldReload: false)
  }

  // MARK: RatchetToolbarModeView

  func ratchetToolbar(didUpdate ratchet: RBRatchet) {
    projectDataDidChange(shouldReload: false)
  }

  // MARK: TransposeToolbarModeView

  func transposeToolbar(didUpdate transpose: Int) {
    projectDataDidChange(shouldReload: false)
  }

  // MARK: RecordToolbarModeView

  func recordToolbarDidAddRecording() {
    gridView.reloadData()
  }

  func recordToolbarDidUpdateRecording(duration: Double) {
    let index = (projectData?.rhythm.count ?? 0) - 1
    guard index >= 0 else { return }
    gridView.updateDurationOfCell(at: index, duration: duration)
  }

  func recordToolbarDidEndRecording() {
    gridView.snapRangeheadToLastCell()
    gridView.fixOverlaps()
    updateToolbar()
    projectDataDidChange()
  }

  // MARK: SnapshotToolbarModeView

  func snapshotToolbarDidPressAddButton() {
    projectData?.snapshot()
    updateToolbar()
  }

  func snapshotToolbarDidPressMIDICCButton() {
    let pickerData = PickerData(
      title: i18n.snapshotMIDICCSettingsTitle.description,
      rows: [Int](0..<128).map({ "CC#\($0)" }),
      initialSelectionIndex: 0,
      cancelCallback: nil,
      doneCallback: { item, index in
        DispatchQueue.main.async {
          self.projectData?.snapshotData.cc = index
          self.updateToolbar()
        }
      })
    presentPicker(data: pickerData)
  }

  func snapshotToolbarDidSelectSnapshot(at index: Int) {
    guard let snapshot = projectData?.snapshotData.snapshots[safe: index]?.copy() else { return }
    projectData?.rhythm = snapshot.rhythmData
    projectData?.duration = snapshot.duration
    gridView.unselectCells()
    projectDataDidChange()
  }

  func snapshotToolbarDidDeleteSnapshot(at index: Int) {
    guard projectData?.snapshotData.snapshots.indices.contains(index) == true else { return }
    projectData?.snapshotData.snapshots.remove(at: index)
    projectDataDidChange()
    updateToolbar()
  }

  func snapshotToolbarDidRequestSnapshotImage(at index: Int) -> UIImage? {
    guard let data = projectData?.snapshotData.snapshots[safe: index] else { return nil }
    let width: CGFloat = 100
    let padding: CGFloat = 8
    let rect = CGRect(x: 0, y: 0, width: width, height: width)
    UIGraphicsBeginImageContextWithOptions(rect.size, true, UIScreen.main.scale)

    let scale = width / CGFloat(data.duration)
    let context = UIGraphicsGetCurrentContext()
    context?.setFillColor(UIColor.gridBackgroundColor.cgColor)
    context?.fill(rect)

    // Draw lines
    for rhythm in data.rhythmData {
      let sepWidth = 1.0 / UIScreen.main.scale
      let position = (CGFloat(rhythm.position) * scale)
      let duration = (CGFloat(rhythm.duration) * scale)
      let height = width - (padding * 2)
      // First border
      context?.setFillColor(UIColor.rhythmCellBorderColor.cgColor)
      var border = CGRect(
        x: position,
        y: padding,
        width: sepWidth,
        height: height)
      context?.fill(border)

      // Cell
      context?.setFillColor(UIColor.rhythmCellBackgroundColor.cgColor)
      let cell = CGRect(
        x: position + sepWidth,
        y: padding,
        width: duration - (sepWidth * 2),
        height: height)
      context?.fill(cell)

      // Last border
      context?.setFillColor(UIColor.rhythmCellBorderColor.cgColor)
      border = CGRect(
        x: position + duration - sepWidth,
        y: padding,
        width: sepWidth,
        height: height)
      context?.fill(border)
    }

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
  }
}
