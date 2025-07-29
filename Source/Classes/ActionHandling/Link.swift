//
//  Link.swift
//  Nantes
//
//  Created by Chris Hansen on 5/8/19.
//  Copyright © 2019 Instacart. All rights reserved.
//

import UIKit

extension NantesLabel {
    public typealias LinkTappedBlock = ((NantesLabel, NantesLabel.Link) -> Void)

    public struct Link: Equatable {
        public var attributes: [NSAttributedString.Key: Any]
        public var activeAttributes: [NSAttributedString.Key: Any]
        public var inactiveAttributes: [NSAttributedString.Key: Any]
        public var linkTappedBlock: NantesLabel.LinkTappedBlock?
        public var result: NSTextCheckingResult?
        public var text: String?

        public init(attributes: [NSAttributedString.Key: Any]?, activeAttributes: [NSAttributedString.Key: Any]?, inactiveAttributes: [NSAttributedString.Key: Any]?, linkTappedBlock: NantesLabel.LinkTappedBlock?, result: NSTextCheckingResult?, text: String?) {
            self.attributes = attributes ?? [:]
            self.activeAttributes = activeAttributes ?? [:]
            self.inactiveAttributes = inactiveAttributes ?? [:]
            self.linkTappedBlock = linkTappedBlock
            self.result = result
            self.text = text
        }

        public init(label: NantesLabel, result: NSTextCheckingResult?, text: String?) {
            self.init(attributes: label.linkAttributes, activeAttributes: label.activeLinkAttributes, inactiveAttributes: label.inactiveLinkAttributes, linkTappedBlock: nil, result: result, text: text)
        }

        public static func == (lhs: NantesLabel.Link, rhs: NantesLabel.Link) -> Bool {
            return (lhs.attributes as NSDictionary).isEqual(to: rhs.attributes) &&
                (lhs.activeAttributes as NSDictionary).isEqual(to: rhs.activeAttributes) &&
                (lhs.inactiveAttributes as NSDictionary).isEqual(to: rhs.inactiveAttributes) &&
                lhs.result?.range == rhs.result?.range &&
                lhs.text == rhs.text
        }
    }

    /// Adds a single link
    open func addLink(_ link: NantesLabel.Link) {
        addLinks([link])
    }

    /// Adds a link to a `url` with a specified `range`
    @discardableResult
    open func addLink(to url: URL, withRange range: NSRange) -> NantesLabel.Link? {
        return addLinks(with: [.linkCheckingResult(range: range, url: url)], withAttributes: linkAttributes).first
    }

    @discardableResult
    private func addLinks(with textCheckingResults: [NSTextCheckingResult], withAttributes attributes: [NSAttributedString.Key: Any]?) -> [NantesLabel.Link] {
        var links: [NantesLabel.Link] = []

        for result in textCheckingResults {
            var text = self.text

            if let checkingText = self.text, let range = Range(result.range, in: checkingText) {
                text = String(checkingText[range])
            }

            let link = NantesLabel.Link(attributes: attributes, activeAttributes: activeLinkAttributes, inactiveAttributes: inactiveLinkAttributes, linkTappedBlock: nil, result: result, text: text)
            links.append(link)
        }

        addLinks(links)

        return links
    }

    private func addLinks(_ links: [NantesLabel.Link]) {
        guard let attributedText = attributedText?.mutableCopy() as? NSMutableAttributedString else {
            return
        }

        for link in links {
            let attributes = link.attributes

            guard let range = link.result?.range else {
                continue
            }

            attributedText.addAttributes(attributes, range: range)
        }

        linkModels.append(contentsOf: links)

        _attributedText = attributedText
        setNeedsFramesetter()
        setNeedsDisplay()
    }

    /// Finds the link at the character index
    ///
    /// returns nil if there's no link
    private func link(at characterIndex: Int) -> NantesLabel.Link? {
        // Skip if the index is outside the bounds of the text
        guard let attributedText = attributedText,
            NSLocationInRange(characterIndex, NSRange(location: 0, length: attributedText.length)) else {
                return nil
        }

        for link in linkModels {
            guard let range = link.result?.range else {
                continue
            }

            if NSLocationInRange(characterIndex, range) {
                return link
            }
        }

        return nil
    }

    public func truncationToken(at point: CGPoint) -> Bool {
        guard !truncation.isHidden else {
            return false
        }
        let index = characterIndex(at: point)
        let value = truncation.range.contains(index)
        return value
    }
    
    /// Tries to find the link at a point
    ///
    /// returns nil if there's no link
    public func link(at point: CGPoint) -> NantesLabel.Link? {
        guard !linkModels.isEmpty,
              bounds.inset(by: UIEdgeInsets(top: -15, left: -15, bottom: -15, right: -15)).contains(point) else {
            return nil
        }

        // TTTAttributedLabel also does some extra bounds checking around where the point happened
        // if we can't find the link at the point depending on extendsLinkTouchArea being true
        // it adds a lot of extra checks and we're not using it right now, so I'm skipping it
        return link(at: characterIndex(at: point))
    }

    func didSetActiveLink(activeLink: NantesLabel.Link?, oldValue: NantesLabel.Link?) {
        let linkAttributes = activeLink?.activeAttributes.isEmpty == false ? activeLink?.activeAttributes : activeLinkAttributes
        guard let activeLink = activeLink,
            let attributes = linkAttributes,
            attributes.isEmpty == false else {
                if inactiveAttributedText != nil {
                    _attributedText = inactiveAttributedText
                    inactiveAttributedText = nil
                    setNeedsFramesetter()
                    setNeedsDisplay()
                }
                return
        }

        if inactiveAttributedText == nil {
            inactiveAttributedText = attributedText?.copy() as? NSAttributedString
        }

        guard let updatedAttributedString = attributedText?.mutableCopy() as? NSMutableAttributedString else {
            return
        }

        guard let linkResultRange = activeLink.result?.range else {
            return
        }

        guard linkResultRange.length > 0 &&
            NSLocationInRange(NSMaxRange(linkResultRange) - 1, NSRange(location: 0, length: updatedAttributedString.length)) else {
                return
        }

        updatedAttributedString.addAttributes(attributes, range: linkResultRange)

        _attributedText = updatedAttributedString
        setNeedsFramesetter()
        setNeedsDisplay()
        CATransaction.flush()
    }

    func checkText() {
        guard let attributedText = attributedText,
            !enabledTextCheckingTypes.isEmpty else {
                return
        }

        DispatchQueue.global(qos: .default).async { [weak self] in
            guard let self = self else {
                return
            }

            guard let dataDetector = self.dataDetector else {
                return
            }
            let detectorResult = attributedText.findCheckingResults(usingDetector: dataDetector)
            let existingLinks = attributedText.findExistingLinks()
            let results = detectorResult.union(existingLinks)

            guard !results.isEmpty else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard self?.attributedText?.string == attributedText.string else {
                    // The string changed, these results aren't useful
                    return
                }
                self?.addLinks(with: Array(results), withAttributes: self?.linkAttributes)
            }
        }
    }
    
    private func characterIndex(at point: CGPoint) -> Int {
        // 1. 快速失败：点必须在 bounds 内
        guard bounds.contains(point),
              let attributedText = attributedText,
              !attributedText.string.isEmpty else {
            return NSNotFound
        }

        // 2. 计算文本绘制区域
        let textRect = self.textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
        guard textRect.contains(point) else {
            return NSNotFound
        }

        // 3. 准备 Core Text 对象
        guard let framesetter = framesetter else {
            return NSNotFound
        }

        // 4. 翻转坐标系（Core Text 原点在左下角）
        var relativePoint = CGPoint(
            x: point.x - textRect.origin.x,
            y: textRect.maxY - point.y      // 注意这里是 maxY - y，确保翻转正确
        )

        // 5. 创建 CTFrame
        let path = CGMutablePath()
        path.addRect(textRect)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributedText.length),
            path,
            nil
        )

        // 6. 获取行信息
        guard let lines = CTFrameGetLines(frame) as? [CTLine],
              !lines.isEmpty else {
            return NSNotFound
        }

        let lineCount = numberOfLines > 0 ? min(numberOfLines, lines.count) : lines.count
        var lineOrigins = [CGPoint](repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: lineCount), &lineOrigins)

        // 7. 遍历行查找点击位置
        for (index, line) in lines.prefix(lineCount).enumerated() {
            let lineOrigin = lineOrigins[index]

            // 获取行排版信息
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

            // 计算行区域
            let yMin = lineOrigin.y - descent
            let yMax = lineOrigin.y + ascent

            // 横向对齐偏移（如居中对齐）
            let flushFactor = textAlignment == .center ? 0.5 :
                              textAlignment == .right  ? 1.0 : 0.0
            let penOffset = CGFloat(CTLineGetPenOffsetForFlush(line, flushFactor, Double(textRect.width)))
            let lineLeft = lineOrigin.x + penOffset
            let lineRight = lineLeft + width

            // 检查 y 和 x 是否在行内
            guard relativePoint.y >= yMin,
                  relativePoint.y <= yMax,
                  relativePoint.x >= lineLeft,
                  relativePoint.x <= lineRight else {
                continue
            }

            // 计算字符索引
            let position = CGPoint(x: relativePoint.x - lineLeft, y: relativePoint.y - lineOrigin.y)
            let charIndex = CTLineGetStringIndexForPosition(line, position)

            // 确保索引有效
            guard charIndex != NSNotFound,
                  charIndex < attributedText.length else {
                return NSNotFound
            }

            return charIndex
        }

        return NSNotFound
    }

}

extension NSAttributedString {
    func findExistingLinks() -> Set<NSTextCheckingResult> {
        var relinks: Set<NSTextCheckingResult> = []
        enumerateAttribute(.link, in: NSRange(location: 0, length: length), options: []) { attribute, linkRange, _ in
            let url: URL
            if let urlAttribute = attribute as? URL {
                url = urlAttribute
            } else if let stringAttribute = attribute as? String, let urlAttribute = URL(string: stringAttribute) {
                url = urlAttribute
            } else {
                return
            }
            relinks.insert(NSTextCheckingResult.linkCheckingResult(range: linkRange, url: url))
        }
        return relinks
    }
}
