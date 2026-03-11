//
//  PDFExportService.swift
//  solyn
//
//  Generates PDF exports of diary entries.
//  PDFs are created locally and stored in temporary directory until shared.
//
//  Privacy: PDF generation happens entirely on-device.
//  Files are stored in temp directory and cleaned up by iOS.
//

#if os(iOS)
import Foundation
import UIKit

/// Paper size options for PDF export
enum PDFPaperSize: String, CaseIterable, Identifiable {
    case a4 = "A4"
    case a5 = "A5"

    var id: String { rawValue }

    var pageRect: CGRect {
        switch self {
        case .a4:
            return CGRect(x: 0, y: 0, width: 595, height: 842)
        case .a5:
            return CGRect(x: 0, y: 0, width: 420, height: 595)
        }
    }
}

struct PDFExportService {
    private static let footerText = "Created with DailyVox"
    private static let margin: CGFloat = 40
    private static let footerHeight: CGFloat = 30

    // Maximum characters per text chunk to avoid memory issues with very long entries
    private static let maxChunkSize = 5000

    enum DateRange {
        case year(Int)
        case quarter(year: Int, quarter: Int)
        case month(year: Int, month: Int)

        var startDate: Date {
            let calendar = Calendar.current
            var components = DateComponents()

            switch self {
            case .year(let year):
                components.year = year
                components.month = 1
                components.day = 1
            case .quarter(let year, let quarter):
                components.year = year
                components.month = (quarter - 1) * 3 + 1
                components.day = 1
            case .month(let year, let month):
                components.year = year
                components.month = month
                components.day = 1
            }

            return calendar.date(from: components) ?? Date.distantPast
        }

        var endDate: Date {
            let calendar = Calendar.current
            var components = DateComponents()

            switch self {
            case .year(let year):
                components.year = year
                components.month = 12
                components.day = 31
            case .quarter(let year, let quarter):
                components.year = year
                components.month = quarter * 3
                components.day = 1
                if let date = calendar.date(from: components),
                   let lastDay = calendar.range(of: .day, in: .month, for: date)?.upperBound {
                    components.day = lastDay - 1
                }
            case .month(let year, let month):
                components.year = year
                components.month = month
                components.day = 1
                if let date = calendar.date(from: components),
                   let lastDay = calendar.range(of: .day, in: .month, for: date)?.upperBound {
                    components.day = lastDay - 1
                }
            }

            return calendar.date(from: components) ?? Date.distantFuture
        }

        func contains(_ date: Date) -> Bool {
            return date >= startDate && date <= endDate
        }
    }

    static func generatePDF(
        for entries: [DiaryEntry],
        dateRange: DateRange,
        periodTitle: String,
        paperSize: PDFPaperSize,
        authorName: String? = nil,
        authorDescription: String? = nil
    ) throws -> URL {
        let filteredEntries = entries.filter { entry in
            guard let date = entry.date else { return false }
            return dateRange.contains(date)
        }.sorted { (lhs, rhs) in
            (lhs.date ?? .distantPast) < (rhs.date ?? .distantPast)
        }

        let format = UIGraphicsPDFRendererFormat()
        let pageRect = paperSize.pageRect
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        let exportDateFormatter = DateFormatter()
        exportDateFormatter.dateFormat = "MMMM d, yyyy"

        let data = renderer.pdfData { context in
            // MARK: - Cover Page
            context.beginPage()
            drawCoverPage(
                context: context,
                pageRect: pageRect,
                periodTitle: periodTitle,
                authorName: authorName,
                authorDescription: authorDescription,
                exportDate: exportDateFormatter.string(from: Date()),
                entryCount: filteredEntries.count
            )

            // MARK: - Content Pages
            var textOrigin = CGPoint(x: margin, y: margin)
            let contentBottom = pageRect.height - margin - footerHeight

            func startNewPage() {
                context.beginPage()
                drawFooter(context: context, pageRect: pageRect)
                textOrigin = CGPoint(x: margin, y: margin)
            }

            func addPageIfNeeded(for additionalHeight: CGFloat) {
                if textOrigin.y + additionalHeight > contentBottom {
                    startNewPage()
                }
            }

            // Start first content page
            startNewPage()

            let bodyFont = UIFont.systemFont(ofSize: 12)
            let dateFont = UIFont.systemFont(ofSize: 12, weight: .semibold)

            for entry in filteredEntries {
                let dateString = dateFormatter.string(from: entry.date ?? Date())
                let dateAttrs: [NSAttributedString.Key: Any] = [
                    .font: dateFont,
                    .foregroundColor: UIColor.darkGray
                ]
                let dateSize = (dateString as NSString).size(withAttributes: dateAttrs)
                addPageIfNeeded(for: dateSize.height + 8)
                (dateString as NSString).draw(at: textOrigin, withAttributes: dateAttrs)
                textOrigin.y += dateSize.height + 6

                if let text = entry.text, !text.isEmpty {
                    let bodyAttrs: [NSAttributedString.Key: Any] = [
                        .font: bodyFont,
                        .foregroundColor: UIColor.black
                    ]
                    let maxWidth = pageRect.width - (margin * 2)

                    // Process text in chunks to handle very long entries
                    let chunks = splitTextIntoChunks(text, maxLength: maxChunkSize)

                    for chunk in chunks {
                        let boundingRect = (chunk as NSString).boundingRect(
                            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: bodyAttrs,
                            context: nil
                        )

                        // Draw text, handling page breaks
                        var remainingHeight = boundingRect.height
                        let textToDraw = chunk

                        while remainingHeight > 0 {
                            let availableHeight = contentBottom - textOrigin.y

                            if availableHeight < 50 {
                                startNewPage()
                                continue
                            }

                            let textRect = CGRect(x: textOrigin.x, y: textOrigin.y, width: maxWidth, height: min(availableHeight, remainingHeight))
                            (textToDraw as NSString).draw(in: textRect, withAttributes: bodyAttrs)

                            if remainingHeight > availableHeight {
                                remainingHeight -= availableHeight
                                startNewPage()
                            } else {
                                textOrigin.y += remainingHeight + 4
                                remainingHeight = 0
                            }
                        }
                    }
                    textOrigin.y += 20
                } else {
                    textOrigin.y += 16
                }

                // Add separator line
                let separatorY = textOrigin.y - 12
                if separatorY < contentBottom {
                    let separatorPath = UIBezierPath()
                    separatorPath.move(to: CGPoint(x: margin, y: separatorY))
                    separatorPath.addLine(to: CGPoint(x: pageRect.width - margin, y: separatorY))
                    UIColor.lightGray.withAlphaComponent(0.3).setStroke()
                    separatorPath.lineWidth = 0.5
                    separatorPath.stroke()
                }
            }
        }

        // Create safe filename from period title
        let safeTitle = periodTitle.replacingOccurrences(of: " ", with: "-")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("DailyVox-\(safeTitle)-\(UUID().uuidString).pdf")
        try data.write(to: tempURL)
        return tempURL
    }

    private static func drawCoverPage(
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        periodTitle: String,
        authorName: String?,
        authorDescription: String?,
        exportDate: String,
        entryCount: Int
    ) {
        let centerX = pageRect.width / 2
        var yPosition: CGFloat = pageRect.height * 0.3

        // App name / Title
        let titleText = "DailyVox"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .light),
            .foregroundColor: UIColor.darkGray
        ]
        let titleSize = (titleText as NSString).size(withAttributes: titleAttrs)
        (titleText as NSString).draw(
            at: CGPoint(x: centerX - titleSize.width / 2, y: yPosition),
            withAttributes: titleAttrs
        )
        yPosition += titleSize.height + 8

        // Period title (year, month, or quarter)
        let periodAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let periodSize = (periodTitle as NSString).size(withAttributes: periodAttrs)
        (periodTitle as NSString).draw(
            at: CGPoint(x: centerX - periodSize.width / 2, y: yPosition),
            withAttributes: periodAttrs
        )
        yPosition += periodSize.height + 40

        // Decorative line
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: centerX - 50, y: yPosition))
        linePath.addLine(to: CGPoint(x: centerX + 50, y: yPosition))
        UIColor.lightGray.setStroke()
        linePath.lineWidth = 1
        linePath.stroke()
        yPosition += 40

        // Author name
        if let name = authorName, !name.isEmpty {
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: UIColor.black
            ]
            let nameSize = (name as NSString).size(withAttributes: nameAttrs)
            (name as NSString).draw(
                at: CGPoint(x: centerX - nameSize.width / 2, y: yPosition),
                withAttributes: nameAttrs
            )
            yPosition += nameSize.height + 8
        }

        // Author description
        if let desc = authorDescription, !desc.isEmpty {
            let descAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 14),
                .foregroundColor: UIColor.gray
            ]
            let descSize = (desc as NSString).size(withAttributes: descAttrs)
            (desc as NSString).draw(
                at: CGPoint(x: centerX - descSize.width / 2, y: yPosition),
                withAttributes: descAttrs
            )
            yPosition += descSize.height + 8
        }

        // Entry count and export date at bottom
        let bottomY = pageRect.height - 80
        let infoAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.gray
        ]

        let countText = "\(entryCount) entr\(entryCount == 1 ? "y" : "ies")"
        let countSize = (countText as NSString).size(withAttributes: infoAttrs)
        (countText as NSString).draw(
            at: CGPoint(x: centerX - countSize.width / 2, y: bottomY),
            withAttributes: infoAttrs
        )

        let dateText = "Exported on \(exportDate)"
        let dateSize = (dateText as NSString).size(withAttributes: infoAttrs)
        (dateText as NSString).draw(
            at: CGPoint(x: centerX - dateSize.width / 2, y: bottomY + 16),
            withAttributes: infoAttrs
        )
    }

    private static func drawFooter(context: UIGraphicsPDFRendererContext, pageRect: CGRect) {
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.lightGray
        ]
        let footerSize = (footerText as NSString).size(withAttributes: footerAttrs)
        let footerY = pageRect.height - margin + 10
        (footerText as NSString).draw(
            at: CGPoint(x: (pageRect.width - footerSize.width) / 2, y: footerY),
            withAttributes: footerAttrs
        )
    }

    /// Splits text into chunks to avoid memory issues with very long strings
    private static func splitTextIntoChunks(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }

        var chunks: [String] = []
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            let remainingLength = text.distance(from: currentIndex, to: text.endIndex)
            let chunkLength = min(maxLength, remainingLength)
            let endIndex = text.index(currentIndex, offsetBy: chunkLength)

            // Try to break at a paragraph or sentence boundary
            var breakIndex = endIndex
            if endIndex < text.endIndex {
                let searchRange = currentIndex..<endIndex
                // Look for paragraph break first
                if let paragraphBreak = text.range(of: "\n\n", options: .backwards, range: searchRange) {
                    breakIndex = paragraphBreak.upperBound
                }
                // Otherwise look for sentence break
                else if let sentenceBreak = text.range(of: ". ", options: .backwards, range: searchRange) {
                    breakIndex = sentenceBreak.upperBound
                }
                // Otherwise look for any newline
                else if let lineBreak = text.range(of: "\n", options: .backwards, range: searchRange) {
                    breakIndex = lineBreak.upperBound
                }
            }

            let chunk = String(text[currentIndex..<breakIndex])
            if !chunk.isEmpty {
                chunks.append(chunk)
            }
            currentIndex = breakIndex
        }

        return chunks
    }
}
#endif
