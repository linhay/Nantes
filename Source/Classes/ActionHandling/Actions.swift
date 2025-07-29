//
//  Actions.swift
//  Nantes
//
//  Created by Chris Hansen on 5/8/19.
//  Copyright © 2019 Instacart. All rights reserved.
//

import UIKit

extension NantesLabel {
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled,
              !isHidden,
              alpha > 0 else {
            return super.hitTest(point, with: event)
        }
        
        if link(at: point) != nil {
            return self
        }
        
        if truncationToken(at: point), self.truncation.action != nil {
            return self
        }
        
        return super.hitTest(point, with: event)
    }

    /// We're handling link touches elsewhere, so we want to do nothing if we end up on a link
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        
        let point = touch.location(in: self)
        
        self.activeLink = nil
        
        if truncationToken(at: point), self.truncation.action != nil {
            self.tappedEvent = .truncation(truncation)
        } else if let activeLink = link(at: point) {
            self.activeLink = activeLink
            self.tappedEvent = .link(activeLink)
        } else if let block = labelTappedBlock {
            self.tappedEvent = .tapped(block)
        } else {
            self.tappedEvent = nil
            super.touchesBegan(touches, with: event)
        }
    }
    
    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeLink = nil
        tappedEvent = nil
        super.touchesCancelled(touches, with: event)
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tappedEvent else {
            return super.touchesEnded(touches, with: event)
        }
        
        switch tappedEvent {
        case .truncation(let truncation):
            truncation.action?()
        case .link(let link):
            handleLinkTapped(link)
        case .tapped(let block):
            super.touchesEnded(touches, with: event)
            block()
        }
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            super.touchesMoved(touches, with: event)
            return
        }
        activeLink = nil
        tappedEvent = nil
    }
    
    func handleLinkTapped(_ link: NantesLabel.Link) {
        guard link.linkTappedBlock == nil else {
            link.linkTappedBlock?(self, link)
            activeLink = nil
            return
        }
        
        guard let result = link.result else {
            return
        }
        
        activeLink = nil
        
        guard let delegate = delegate else {
            return
        }
        
        switch result.resultType {
        case .address:
            if let address = result.addressComponents {
                delegate.attributedLabel(self, didSelectAddress: address)
            }
        case .date:
            if let date = result.date {
                delegate.attributedLabel(self, didSelectDate: date, timeZone: result.timeZone ?? TimeZone.current, duration: result.duration)
            }
        case .link:
            if let url = result.url {
                delegate.attributedLabel(self, didSelectLink: url)
            }
        case .phoneNumber:
            if let phoneNumber = result.phoneNumber {
                delegate.attributedLabel(self, didSelectPhoneNumber: phoneNumber)
            }
        case .transitInformation:
            if let transitInfo = result.components {
                delegate.attributedLabel(self, didSelectTransitInfo: transitInfo)
            }
        default: // fallback to result if we aren't sure
            delegate.attributedLabel(self, didSelectTextCheckingResult: result)
        }
    }
}
