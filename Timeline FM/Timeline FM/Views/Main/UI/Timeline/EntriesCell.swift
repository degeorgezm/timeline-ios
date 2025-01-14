//
//  TimesheetEntryCell.swift
//  Timesheets
//
//  Created by Zachary DeGeorge on 6/15/18.
//  Copyright © 2018 Next Day Project. All rights reserved.
//

import Material
import UIKit
import MapKit

class EntriesCell: UITableViewCell, ThemeSupportedProtocol, NibProtocol {
    typealias Item = EntriesCell
    static var reuseIdentifier: String = "EntriesCell"
    static var cellHeight: CGFloat = 75

    @IBOutlet var icon: UIImageView!
    @IBOutlet var timelineTop: UIView!
    @IBOutlet var timelineBottom: UIView!

    @IBOutlet var activityName: UILabel!
    @IBOutlet var locationName: UILabel!
    @IBOutlet var locationAddress: UILabel!
    @IBOutlet var duration: UILabel!
    @IBOutlet var timespan: UILabel!

    @IBOutlet var imageView1: UIImageView!
    @IBOutlet var imageView2: UIImageView!
    @IBOutlet var imageView3: UIImageView!
    @IBOutlet var imageView4: UIImageView!
    @IBOutlet var imageView5: UIImageView!
    @IBOutlet var imageView6: UIImageView!

    var images = [UIImageView]()

    var sheet: Sheet?
    var index: Int?
    var threeDTouchAvailable: Bool = false

    var baseFontSize: CGFloat = 12.0
    var titleFontDifference: CGFloat = 2.0

    let formatter = DateFormatter()
    
    var timer_1000ms: Timer?
    
    override func awakeFromNib() {
        super.awakeFromNib()

        formatter.dateFormat = "h:mm a"

        images.append(imageView1)
        images.append(imageView2)
        images.append(imageView3)
        images.append(imageView4)
        images.append(imageView5)
        images.append(imageView6)

        for image in images { clearImage(image) }

        icon.backgroundColor = UIColor.clear

        let fontSize: CGFloat = baseFontSize

        activityName.font = activityName.font.withSize(fontSize + titleFontDifference)
        locationName.font = locationName.font.withSize(fontSize)

        locationAddress.font = locationAddress.font.withSize(fontSize)
        duration.font = duration.font.withSize(fontSize)
        timespan.font = timespan.font.withSize(fontSize)
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(reviewEntry)))
        Theme.shared.theme_changed.observe(self, selector: #selector(applyTheme))
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        super.setSelected(false, animated: true)
        // Configure the view for the selected state
    }
    
    override func setHighlighted(_: Bool, animated _: Bool) {
        super.setHighlighted(false, animated: false)
    }

    func clearImage(_ image: UIImageView) {
        image.image = nil
        image.alpha = 0.0
    }

    func populateImages() {
        for image in images { clearImage(image) }

        if let index = self.index, let entry = self.sheet?.entries.items[index] {
            var i: Int = 0

            if entry.autoGenerated == true {
                images[i].image = AssetManager.shared.iconAuto
                images[i].alpha = 1.0
                i += 1
            }
            if entry.paidTime == false {
                images[i].image = AssetManager.shared.iconUnpaid
                images[i].alpha = 1.0
                i += 1
            }

            if entry.userEdited == true {
                images[i].image = AssetManager.shared.iconEdited
                images[i].alpha = 1.0
                i += 1
            }

            if entry.photos.count > 0 {
                images[i].image = AssetManager.shared.iconPhotos
                images[i].alpha = 1.0
                i += 1
            }

            if entry.breadcrumbs.count > 0 {
                images[i].image = AssetManager.shared.iconBreadcrumbs
                images[i].alpha = 1.0
                i += 1
            }
        }
    }

    @objc func update() {
        DispatchQueue.main.async {
            self.updateValues()
        }
    }

    func updateValues() {
        guard let sheet = self.sheet, let index = self.index, let entries = sheet.entries, index < entries.count, let activity = entries.items[index].activity else {
            icon.image = nil
            locationName.text = nil
            locationAddress.text = nil
            self.activityName.text = nil
            for image in images { clearImage(image) }
            return
        }

        let entry = sheet.entries.items[index]
        self.activityName.text = activity.name

        if self.index == 0 {
            timelineTop.alpha = 0
        } else {
            timelineTop.alpha = 1.0
        }

        if self.index! == self.sheet!.entries.count - 1 {
            timelineBottom.alpha = 0
        } else {
            timelineBottom.alpha = 1.0
        }

        if !activity.breaking, !activity.traveling {
            self.activityName.textColor = Theme.shared.active.primaryFontColor
            if let location = entry.location, let locationName = location.name, let addressString = location.addressString {
                self.locationName.text = locationName
                locationAddress.text = addressString
            }
        } else {
            if activity.traveling {
                self.activityName.textColor = Color.blue.darken3
                locationName.text = String(format: "%0.1f miles", arguments: [entry.meters * CONVERSION_METERS_TO_MILES_MULTIPLIER])
                locationAddress.text = nil
            } else if activity.breaking {
                self.activityName.textColor = Color.deepOrange.darken3
                locationName.text = "Private"
                locationAddress.text = nil
            }
        }

        // Set duration string
        if let seconds = sheet.duration(index: index) {
            let durationString = String(format: "%.0fh %0.fm %.0fs", arguments: [clockHours(seconds), clockMinutes(seconds), clockSeconds(seconds)])
            duration.text = durationString
        } else {
            duration.text = nil
        }

        // Set timespan string
        var timespanText: String?
        if index == 0, sheet.submissionDate == nil, let startString = entry.startString {
            timespanText = String(format: "%@ - Present", arguments: [startString])
        } else if index == 0, self.sheet?.submissionDate != nil, let start = entry.start, let end = self.sheet?.submissionDate {
            timespanText = String(format: "%@ - %@", arguments: [self.formatter.string(from: start), self.formatter.string(from: end)])
        } else if let previousEntry = self.sheet?.entries[index - 1], let previousStartString = previousEntry.startString, let startString = entry.startString {
            timespanText = String(format: "%@ - %@", arguments: [startString, previousStartString])
        }

        timespan.text = timespanText
    }

    func updateIcon() {
        guard let entry = self.sheet?.entries[self.index] else {
            return
        }

        if entry.activity?.traveling == true {
            // grab snapshot with breadcrumbs overlayed
            travelingSnapshot(size: CGSize(width: 100, height: 100), entry: entry) { (success, image) in
                guard success == true, image != nil else {
                    return
                }
                
                self.icon.setImage(image: image)
            }
        } else {
            
            if entry.activity?.breaking == true {
                icon.setImage(image: AssetManager.shared.breakIcon)
            } else {
                icon.setImage(image: AssetManager.shared.activityGlyph)
                icon.contentMode = .scaleAspectFit
                icon.backgroundColor = UIColor.white
                icon.tintColor = UIColor.black
            }
        }
    }

    override func didMoveToSuperview() {
        // bottom
        let circlePath = UIBezierPath(arcCenter: CGPoint(x: icon.frame.bma_center.x, y: icon.frame.bma_center.y + 5.0), radius: (icon.height / 2.0) + 4.0, startAngle: CGFloat((Double.pi / 2) - (Double.pi / 6)), endAngle: CGFloat((Double.pi / 2) + (Double.pi / 6)), clockwise: true)
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = circlePath.cgPath

        // change the fill color
        shapeLayer.fillColor = UIColor.clear.cgColor
        // you can change the stroke color
        shapeLayer.strokeColor = Color.blue.lighten1.withAlphaComponent(1.0).cgColor
        // you can change the line width
        shapeLayer.lineWidth = 2.0
        shapeLayer.opacity = 1.0
        contentView.layer.addSublayer(shapeLayer)

        // top
        let circlePath2 = UIBezierPath(arcCenter: CGPoint(x: icon.frame.bma_center.x, y: icon.frame.bma_center.y + 5.0), radius: (icon.height / 2.0) + 4.0, startAngle: CGFloat(-(Double.pi / 2) - (Double.pi / 6)), endAngle: CGFloat(-(Double.pi / 2) + (Double.pi / 6)), clockwise: true)
        let shapeLayer2 = CAShapeLayer()
        shapeLayer2.path = circlePath2.cgPath

        // change the fill color
        shapeLayer2.fillColor = UIColor.clear.cgColor
        // you can change the stroke color
        shapeLayer2.strokeColor = Color.blue.lighten1.withAlphaComponent(1.0).cgColor
        // you can change the line width
        shapeLayer2.lineWidth = 2.0
        shapeLayer2.opacity = 1.0
        contentView.layer.addSublayer(shapeLayer2)
    }

    func clear() {
        activityName.text = nil
        duration.text = nil
        icon.image = nil
        locationName.text = nil
        locationAddress.text = nil
        timespan.text = nil
        sheet = nil
        index = nil
    }

    func populate(_ sheet: Sheet?, index: Int) {
        self.sheet = sheet
        self.index = index
        
        updateIcon()
        populateImages()
        updateValues()
        applyTheme()

        for layer in icon.layer.sublayers ?? [] {
            if layer is CAShapeLayer {
                layer.removeFromSuperlayer()
            }
        }
    }
    
    @objc func reviewEntry(_ sender: UITapGestureRecognizer) {
        guard let cell = sender.view as? EntriesCell, let sheet = cell.sheet, let index = cell.index else {
            return
        }
        
        Generator.bump()
        cell.setSelected(true, animated: true)
        
        let destination = UIStoryboard.Main(identifier: "EntryReview") as! EntryReview
        
        destination.sheet = sheet
        destination.index = index
        destination.entry = sheet.entries.items[index]
        
        Presenter.push(destination, animated: true, completion: nil)
    }
    
    var updates: Bool = false {
        willSet {
            guard newValue != updates else {
                return
            }
            
            switch newValue {
            case true:
                timer_1000ms?.invalidate()
                timer_1000ms = nil
                timer_1000ms = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
                    
                    print("Timer - Entries Cell")
                    
                    self.update()
                })
                timer_1000ms?.fire()
                break
            case false:
                timer_1000ms?.invalidate()
                timer_1000ms = nil
            }
        }
    }
    
    
    // Create Map Snapshot with Breadcrumbs Overlay
    
    func travelingSnapshot(size: CGSize, entry: Entry, _ callback: @escaping (_ success: Bool, _ image: UIImage?) -> Void) {
        guard let region = entry.region else {
            callback(false, nil)
            return
        }
        
        let options = MKMapSnapshotOptions()
        options.mapType = .mutedStandard
        options.region = region
        options.size = size
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start(with: DispatchQueue.global(qos: .background)) { snapshot, error in
            guard error == nil else {
                callback(false, nil)
                return
            }
            
            guard var image = snapshot?.image else {
                callback(false, nil)
                return
            }
            
            if entry.breadcrumbs.count > 0 {
                let points = entry.breadcrumbs.coordinates
                UIGraphicsBeginImageContext(image.size)
                let renderer = UIGraphicsImageRenderer(size: image.size)
                let overlay = renderer.image { context in
                    
                    context.cgContext.setLineWidth(size.height * 0.035)
                    context.cgContext.setStrokeColor(entry.overlayColor?.withAlphaComponent(0.9).cgColor ?? UIColor.blue.withAlphaComponent(0.9).cgColor)
                    
                    if let cgpoint = snapshot?.point(for: points[0]) {
                        context.cgContext.move(to: cgpoint)
                    }
                    
                    for point in points {
                        if let cgpoint = snapshot?.point(for: point) {
                            context.cgContext.addLine(to: cgpoint)
                        }
                    }
                    
                    context.cgContext.strokePath()
                }
                
                UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
                
                image.draw(at: CGPoint.zero)
                overlay.draw(at: CGPoint.zero)
                
                image = UIGraphicsGetImageFromCurrentImageContext()!
                
                callback(true, image)
            } else {
                UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
                
                image.draw(at: CGPoint.zero)
                
                image = UIGraphicsGetImageFromCurrentImageContext()!
                
                callback(true, image)
            }
        }
    }

    @objc func applyTheme() {
        locationName.textColor = Theme.shared.active.secondaryFontColor
        locationAddress.textColor = Theme.shared.active.secondaryFontColor
        duration.textColor = Theme.shared.active.secondaryFontColor
        timespan.textColor = Theme.shared.active.secondaryFontColor

        timelineTop.backgroundColor = Color.blue.lighten1.withAlphaComponent(1.0)
        timelineBottom.backgroundColor = Color.blue.lighten1.withAlphaComponent(1.0)

        activityName.autoResize()
        locationName.autoResize()
        locationAddress.autoResize()
        duration.autoResize()
        timespan.autoResize()
    }

    deinit {
        timer_1000ms?.invalidate()
        timer_1000ms = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        self.clear()
    }
}
