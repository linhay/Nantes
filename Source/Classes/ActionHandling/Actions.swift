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
              alpha > 0,
              link(at: point) != nil || truncationToken(at: point) else {
            return super.hitTest(point, with: event)
        }
        return self
    }
    
    /// We're handling link touches elsewhere, so we want to do nothing if we end up on a link
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        
        let point = touch.location(in: self)
        
        self.activeLink = nil
        self.truncation.tapping = false
        
        if truncationToken(at: point),
           self.truncation.action != nil {
            self.truncation.tapping = true
            return
        }
        
        if let activeLink = link(at: point) {
            self.activeLink = activeLink
            return
        }
        
        if labelTappedBlock == nil {
            super.touchesBegan(touches, with: event)
        }
    }
    
    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if activeLink != nil {
            activeLink = nil
            return
        }
        
        if truncation.tapping {
            truncation.tapping = false
            return
        }
        super.touchesCancelled(touches, with: event)
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let activeLink = activeLink {
            handleLinkTapped(activeLink)
            return
        }
        
        if truncation.tapping {
            truncation.action?()
            return
        }
        
        super.touchesEnded(touches, with: event)
        labelTappedBlock?()
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            super.touchesMoved(touches, with: event)
            return
        }
        let point = touch.location(in: self)
        
        if let activeLink = activeLink,
           let link = link(at: point),
           activeLink != link {
            self.activeLink = nil
        }
        
        if truncation.tapping,
           !truncationToken(at: point) {
            self.truncation.tapping = false
        }
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
