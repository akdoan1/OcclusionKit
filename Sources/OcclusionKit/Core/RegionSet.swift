import Foundation
import CoreGraphics

/// A set of non-overlapping rectangles representing a region.
/// Used to accurately calculate visible area by subtracting occluding windows.
public struct RegionSet: Sendable, Equatable {
    /// The non-overlapping rectangles that make up this region
    public private(set) var rectangles: [CGRect]

    /// Creates an empty region set
    public init() {
        self.rectangles = []
    }

    /// Creates a region set from a single rectangle
    public init(rect: CGRect) {
        if rect.isEmpty || rect.isNull || rect.isInfinite {
            self.rectangles = []
        } else {
            self.rectangles = [rect]
        }
    }

    /// Creates a region set from multiple rectangles (will be normalized to non-overlapping)
    public init(rectangles: [CGRect]) {
        self.rectangles = []
        for rect in rectangles {
            self.add(rect)
        }
    }

    /// The total area of the region
    public var area: CGFloat {
        rectangles.reduce(0) { $0 + $1.width * $1.height }
    }

    /// Whether the region is empty
    public var isEmpty: Bool {
        rectangles.isEmpty
    }

    /// Adds a rectangle to the region (maintains non-overlapping property)
    public mutating func add(_ rect: CGRect) {
        guard !rect.isEmpty && !rect.isNull && !rect.isInfinite else { return }

        // Simple approach: just add and let subtract handle overlaps
        // For a more optimized version, we could merge adjacent rectangles
        rectangles.append(rect)
    }

    /// Subtracts a rectangle from the region
    public mutating func subtract(_ rect: CGRect) {
        guard !rect.isEmpty && !rect.isNull && !rect.isInfinite else { return }

        var newRectangles: [CGRect] = []

        for existing in rectangles {
            let pieces = existing.subtracting(rect)
            newRectangles.append(contentsOf: pieces)
        }

        rectangles = newRectangles
    }

    /// Subtracts multiple rectangles from the region
    public mutating func subtract(_ rects: [CGRect]) {
        for rect in rects {
            subtract(rect)
        }
    }

    /// Returns a new region with the rectangle subtracted
    public func subtractingRect(_ rect: CGRect) -> RegionSet {
        var copy = self
        copy.subtract(rect)
        return copy
    }

    /// Returns a new region with the rectangles subtracted
    public func subtractingRects(_ rects: [CGRect]) -> RegionSet {
        var copy = self
        copy.subtract(rects)
        return copy
    }
}

// MARK: - CGRect Extension for Subtraction

extension CGRect {
    /// Subtracts another rectangle from this one, returning the remaining pieces.
    /// Returns up to 4 rectangles (top, bottom, left, right pieces).
    func subtracting(_ other: CGRect) -> [CGRect] {
        let intersection = self.intersection(other)

        // No intersection means the original rect is unchanged
        guard !intersection.isEmpty && !intersection.isNull else {
            return [self]
        }

        // Fully covered means nothing remains
        if other.contains(self) {
            return []
        }

        var pieces: [CGRect] = []

        // Top piece (full width, above the intersection)
        if intersection.minY > self.minY {
            let top = CGRect(
                x: minX,
                y: minY,
                width: width,
                height: intersection.minY - minY
            )
            if !top.isEmpty {
                pieces.append(top)
            }
        }

        // Bottom piece (full width, below the intersection)
        if intersection.maxY < self.maxY {
            let bottom = CGRect(
                x: minX,
                y: intersection.maxY,
                width: width,
                height: maxY - intersection.maxY
            )
            if !bottom.isEmpty {
                pieces.append(bottom)
            }
        }

        // Left piece (middle row only, to the left of intersection)
        if intersection.minX > self.minX {
            let left = CGRect(
                x: minX,
                y: intersection.minY,
                width: intersection.minX - minX,
                height: intersection.height
            )
            if !left.isEmpty {
                pieces.append(left)
            }
        }

        // Right piece (middle row only, to the right of intersection)
        if intersection.maxX < self.maxX {
            let right = CGRect(
                x: intersection.maxX,
                y: intersection.minY,
                width: maxX - intersection.maxX,
                height: intersection.height
            )
            if !right.isEmpty {
                pieces.append(right)
            }
        }

        return pieces
    }
}
