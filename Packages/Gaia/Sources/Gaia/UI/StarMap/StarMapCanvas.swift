#if os(iOS)
import MetalKit
import UIKit

/// Sibling overlay keeps the text button accessible without intercepting map gestures.
final class StarMapCanvas: UIView {
    let metalView = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    let selection = StarSelectionOverlay()

    init() {
        super.init(frame: .zero)
        clipsToBounds = true
        for child in [metalView, selection] {
            child.frame = bounds
            child.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(child)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class StarSelectionOverlay: UIView {
    private let ring = CAShapeLayer()
    private let name = UILabel()
    private let details = UIButton(type: .system)
    var onOpenDetails: (() -> Void)?

    init() {
        super.init(frame: .zero)
        isHidden = true
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = UIColor.white.cgColor
        ring.lineWidth = 1
        layer.addSublayer(ring)
        name.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .boldSystemFont(ofSize: 15))
        name.textColor = .white
        name.adjustsFontForContentSizeCategory = true
        name.numberOfLines = 2
        name.lineBreakMode = .byTruncatingMiddle
        name.accessibilityIdentifier = "selected-star-name"
        name.layer.shadowColor = UIColor.black.cgColor
        name.layer.shadowOpacity = 1
        name.layer.shadowRadius = 2
        name.layer.shadowOffset = .zero
        addSubview(name)
        var button = UIButton.Configuration.plain()
        button.title = "Star Data"
        button.image = UIImage(systemName: "arrow.right")
        button.imagePlacement = .trailing
        button.imagePadding = 4
        button.preferredSymbolConfigurationForImage = .init(textStyle: .caption1, scale: .small)
        button.contentInsets = .zero
        button.background = .clear()
        button.baseForegroundColor = .white
        button.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .caption1)
            return attributes
        }
        details.configuration = button
        details.accessibilityLabel = "Star Data"
        details.titleLabel?.adjustsFontForContentSizeCategory = true
        details.contentHorizontalAlignment = .leading
        details.contentVerticalAlignment = .top
        details.tintColor = .white
        details.layer.shadowColor = UIColor.black.cgColor
        details.layer.shadowOpacity = 1
        details.layer.shadowRadius = 2
        details.layer.shadowOffset = .zero
        details.accessibilityIdentifier = "selected-star-data"
        details.addTarget(self, action: #selector(openDetails), for: .touchUpInside)
        addSubview(details)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        !isHidden && details.frame.contains(point)
    }

    func show(star: Star, point: SIMD2<Float>, diameter: Float) {
        isHidden = false
        name.text = star.title
        details.accessibilityHint = "Open measurements for \(star.title)"
        let centre = CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
        let radius = max(9, CGFloat(diameter) / 2 + 4)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.path = UIBezierPath(ovalIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                                               width: radius * 2, height: radius * 2)).cgPath
        CATransaction.commit()
        let leftSpace = centre.x - radius - 16
        let rightSpace = bounds.width - centre.x - radius - 16
        let usesLeft = leftSpace > rightSpace
        let width = min(220, max(44, usesLeft ? leftSpace : rightSpace))
        let x = usesLeft ? centre.x - radius - 8 - width : centre.x + radius + 8
        name.textAlignment = usesLeft ? .right : .left
        details.contentHorizontalAlignment = usesLeft ? .right : .left
        let labelHeight = name.sizeThatFits(CGSize(width: width, height: name.font.lineHeight * 2)).height
        let y = min(max(8, centre.y - labelHeight), max(8, bounds.height - labelHeight - 44 - 8))
        name.frame = CGRect(x: x, y: y, width: width, height: labelHeight)
        let buttonWidth = min(width, 100)
        details.frame = CGRect(x: usesLeft ? x + width - buttonWidth : x, y: y + labelHeight + 4,
                               width: buttonWidth, height: 44)
    }

    @objc private func openDetails() { onOpenDetails?() }
}
#endif
