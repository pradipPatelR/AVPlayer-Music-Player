//
//  ProgressSlider.swift
//  MusicPlayerDemo
//

import UIKit

class ProgressSlider: UISlider {
    
    var progressBarAnimatedProgress: Bool = true
    
    var playableProgress: Float {
        get {
            return progressBar.progress
        }
        set (newProgress) {
            if progressBarAnimatedProgress {
                progressBar.setProgress(newProgress, animated: true)
            } else {
                progressBar.progress = newProgress
            }
            
        }
        
    }
    var changeProgressColor: UIColor? {
        get {
            return progressBar.progressTintColor
        }
        set (newColor) {
            progressBar.progressTintColor = newColor
        }
    }

    let progressBar: UIProgressView = {
        let pBar = UIProgressView(progressViewStyle: .default)
        pBar.progressTintColor = .systemGreen
        pBar.progress = 0
        pBar.trackTintColor = .clear
        pBar.translatesAutoresizingMaskIntoConstraints = false
        pBar.isUserInteractionEnabled = false
        return pBar
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        if self.progressBar.superview == nil {
            self.subviews.first?.addSubview(self.progressBar)
            self.progressBar.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: 1).isActive = true
            self.progressBar.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 1).isActive = true
            self.progressBar.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -1).isActive = true
            self.progressBar.heightAnchor.constraint(equalToConstant: 4).isActive = true
        }
    }
   
  
    override func layoutSubviews() {
        super.layoutSubviews()

        if let idx = self.subviews.first?.subviews.firstIndex(where: { $0 == self.progressBar }),
           idx == 0 {
            self.subviews.first?.exchangeSubview(at: 0, withSubviewAt: 1)
        }
        
    }
    
}
