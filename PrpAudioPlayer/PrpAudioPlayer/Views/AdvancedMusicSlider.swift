//
//  CustomProgressSlider.swift
//  PrpAudioPlayer
//
//  Created by Pradip on 31/12/25.
//

import SwiftUI


struct AdvancedMusicSlider: View {
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var bufferedTime: Double
    @State private var isDragging = false
    
    var minimumTrackTintColor: Color = Color.cyan
    var maximumTrackTintColor: Color = Color.gray.opacity(0.25)
    var thumbTintColor: Color = Color.white
    var bufferTintColor: Color = Color.gray.opacity(0.75)
    
    var onChanged: ((_ isDragg:Bool, _ currentSecond: Double) -> Void)?
    
    private var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    private var bufferedProgress: Double {
        guard duration > 0 else { return 0 }
        return bufferedTime / duration
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Time Labels
            
            GeometryReader { geometry in
                
                let fntSize = geometry.size.height / 1.5
                
                HStack {
                    Text(formatTime(currentTime))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("-\(formatTime(duration - currentTime))")
                        .foregroundColor(.secondary)
                }
                .font(.system(size: fntSize, weight: .regular, design: .rounded))
            }
            
            // Custom Slider with Buffering
            GeometryReader { geometry in
                
                let vwHeight = geometry.size.height
                
                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(maximumTrackTintColor)
                        .frame(height: vwHeight / 2)
                    
                    // Buffered Track
                    Capsule()
                        .fill(bufferTintColor)
                        .frame(width: geometry.size.width * CGFloat(bufferedProgress), height: vwHeight / 2)
                    
                    // Progress Track
                    Capsule()
                        .fill(minimumTrackTintColor)
                        .frame(width: geometry.size.width * CGFloat(progress), height: vwHeight / 2)
                    
                    // Thumb
                    Circle()
                        .fill(thumbTintColor)
                        .frame(width: isDragging ? (vwHeight / 2) : vwHeight, height: isDragging ? (vwHeight / 2) : vwHeight)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(minimumTrackTintColor, lineWidth: 2)
                        )
                        .offset(x: geometry.size.width * CGFloat(progress) - (isDragging ? (vwHeight / 4) : (vwHeight / 2)))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    self.isDragging = true
                                    let percentage = min(max(0, value.location.x / geometry.size.width), 1)
                                    self.currentTime = duration * Double(percentage)
                                    self.onChanged?(true, currentTime)
                                }
                                .onEnded { _ in
                                    withAnimation(.spring()) {
                                        self.isDragging = false
                                        self.onChanged?(false, currentTime)
                                    }
                                }
                        )
                        .animation(.spring(response: 0.3), value: isDragging)
                }
                .frame(height: vwHeight)
            }
        }
        .padding(.horizontal)
    }
    
    private func formatTime(_ time: Double) -> String {
        if time.isInfinite || time.isNaN { return "0:00" }
        
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    AdvancedMusicSlider(currentTime: .constant(10), duration: .constant(120), bufferedTime: .constant(90))
}
