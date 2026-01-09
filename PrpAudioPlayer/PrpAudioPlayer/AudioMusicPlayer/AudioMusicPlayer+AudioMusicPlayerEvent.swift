//
//  AudioMusicPlayer+AudioMusicPlayerEvent.swift
//  PrpAudioPlayer
//
//  Created by Pradip on 30/12/25.
//

import UIKit

/// A lightweight, thread-safe event system used to broadcast
/// audio/music player related events to multiple observers.
///
/// - Generic Parameter AudioMusicPlayerEventObjectType:
///   The type of data sent to subscribers when the event is triggered.
final class AudioMusicPlayerEvent<AudioMusicPlayerEventObjectType> {

    /// Creates a new event instance.
    /// Observers can subscribe to this instance and receive notifications.
    init() {
        
    }
    
    /// Represents a subscription to an `AudioMusicPlayerEvent`.
    /// Holding this object keeps the subscription alive.
    /// Cancelling or deallocating it removes the observer automatically.
    final class Subscription {
        
        /// Weak reference to avoid retain cycles.
        private weak var event: AudioMusicPlayerEvent?
        
        /// Unique identifier for the observer.
        private let id: UUID

        /// Internal initializer used by `AudioMusicPlayerEvent`.
        fileprivate init(event: AudioMusicPlayerEvent, id: UUID) {
            self.event = event
            self.id = id
        }

        /// Cancels the subscription and removes the observer from the event.
        func cancel() {
            self.event?.remove(id)
        }

        /// Automatically cancels the subscription when deallocated.
        deinit {
            self.cancel()
        }
    }

    /// Internal representation of an observer.
    /// Stores the owner weakly to automatically remove
    /// observers whose owners are deallocated.
    private struct Observer {
        
        /// Unique identifier for the observer.
        let id: UUID
        
        /// Weak reference to the owner (usually a view controller).
        weak var owner: AnyObject?
        
        /// Closure executed when the event is notified.
        let closure: (AudioMusicPlayerEventObjectType) -> Void
    }
    
    /// List of active observers.
    private var observers: [Observer] = []
    
    /// Concurrent queue used to ensure thread-safe access
    /// to the observers list.
    private let queue = DispatchQueue.main
//    (
//        label: "audioMusicPlayerEvent.observers.queue",
//        attributes: .concurrent
//    )

    /// Subscribes an owner to the event.
    ///
    /// - Parameters:
    ///   - owner: The object that owns this subscription.
    ///            When deallocated, the observer is removed automatically.
    ///   - closure: The block executed when the event is triggered.
    ///
    /// - Returns: A `Subscription` object used to cancel the observation.
    func subscribe(
        owner: AnyObject,
        closure: @escaping (AudioMusicPlayerEventObjectType) -> Void
    ) -> Subscription {
        
        let id = UUID()
        let observer = Observer(id: id, owner: owner, closure: closure)

        self.queue.async(flags: .barrier) {
            self.observers.append(observer)
        }

        return Subscription(event: self, id: id)
    }

    /// Notifies all active observers with the provided parameters.
    ///
    /// Automatically removes observers whose owners
    /// have already been deallocated.
    ///
    /// - Parameter params: Data passed to each observer.
    func notify(_ params: AudioMusicPlayerEventObjectType) {
        self.queue.async {
            let activeObservers: [Observer] = {
                self.observers = self.observers.filter { $0.owner != nil }
                return self.observers
            }()

            activeObservers.forEach { $0.closure(params) }
        }
    }

    /// Removes an observer with the specified identifier.
    ///
    /// - Parameter id: The unique identifier of the observer to remove.
    private func remove(_ id: UUID) {
        self.queue.async(flags: .barrier) {
            self.observers.removeAll { $0.id == id }
        }
    }
}
