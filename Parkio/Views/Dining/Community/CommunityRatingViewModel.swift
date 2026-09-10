// CommunityRatingViewModel.swift — runtime state for one venue's Community Rating.
//
// Owns everything the Community section shows. Nothing here is persisted: the
// aggregate belongs to the server, the personal rating belongs to the server,
// and the anonymous credential belongs to the Keychain. Deliberately not
// SwiftData and deliberately not the private journal's UserDefaults — see
// CommunityRatingModels.swift for why those are different things.
//
// Two independent state machines rather than a pile of Booleans: what we know
// about the venue, and what the guest is doing about it.

import Foundation
import Observation

@MainActor
@Observable
final class CommunityRatingViewModel {

    // MARK: - Load state

    enum LoadState: Equatable {
        case idle
        case loading
        /// Nobody has rated this venue. A fact, and NOT the same as `unavailable`.
        case zero
        case rated(CommunityRatingAggregate)
        /// Ratings could not be read. The section hides itself rather than
        /// claiming a restaurant has no fans.
        case unavailable
    }

    // MARK: - Form state

    enum FormState: Equatable {
        case closed
        case editing
        case submitting
        case success(DiningRatingWriteOutcome)
        case failure
    }

    private(set) var load: LoadState = .idle
    private(set) var form: FormState = .closed

    /// The guest's own current rating, as the server knows it.
    private(set) var myRating: PersonalDiningRating?

    // Draft values while the sheet is open.
    var draftOverall: Int?
    var draftTaste: Int?
    var draftValue: Int?
    var draftQuality: Int?

    let venueKey: String
    private let service: CommunityRatingService
    private var loadTask: Task<Void, Never>?
    private var hasLoaded = false

    init(venueKey: String, service: CommunityRatingService) {
        self.venueKey = venueKey
        self.service = service
    }

    // No deinit cancellation: the load task captures self weakly, so it
    // cannot keep this alive, and `loadIfNeeded` is idempotent. A
    // MainActor-isolated deinit would not compile anyway.

    // MARK: - Derived

    var canSubmit: Bool {
        guard let draftOverall else { return false }
        return DiningRatingSubmission.starRange.contains(draftOverall) && form != .submitting
    }

    var hasPersonalRating: Bool { myRating != nil }

    /// Only dimensions somebody actually answered. A dimension with count 0 is
    /// omitted rather than shown as 0.0.
    var visibleDimensions: [(name: String, average: Double, count: Int)] {
        guard case .rated(let aggregate) = load else { return [] }
        var rows: [(String, Double, Int)] = []
        if let taste = aggregate.tasteAverage, aggregate.tasteCount > 0 {
            rows.append(("Taste", taste, aggregate.tasteCount))
        }
        if let value = aggregate.valueAverage, aggregate.valueCount > 0 {
            rows.append(("Value", value, aggregate.valueCount))
        }
        if let quality = aggregate.qualityAverage, aggregate.qualityCount > 0 {
            rows.append(("Quality", quality, aggregate.qualityCount))
        }
        return rows.map { (name: $0.0, average: $0.1, count: $0.2) }
    }

    // MARK: - Loading

    /// Idempotent: SwiftUI recomputes bodies freely, and this must not turn
    /// that into a request per redraw.
    func loadIfNeeded() {
        guard !hasLoaded, loadTask == nil else { return }
        loadTask = Task { [weak self] in
            await self?.performLoad()
            self?.loadTask = nil
        }
    }

    private func performLoad() async {
        load = .loading
        do {
            // Public read: sends no credential and provisions none, so simply
            // opening a venue leaves the guest anonymous and uncookied.
            let aggregate = try await service.aggregate(venueKey: venueKey)
            guard !Task.isCancelled else { return }
            load = aggregate.hasRatings ? .rated(aggregate) : .zero
            hasLoaded = true

            // Only asks if a credential already exists; never creates one.
            myRating = try? await service.myRating(venueKey: venueKey)
        } catch {
            guard !Task.isCancelled else { return }
            load = .unavailable
            hasLoaded = true
        }
    }

    // MARK: - Form

    func openForm() {
        draftOverall = myRating?.overall
        draftTaste = myRating?.taste
        draftValue = myRating?.value
        draftQuality = myRating?.quality
        form = .editing
    }

    func closeForm() { form = .closed }

    func submit() async {
        guard let overall = draftOverall else { return }
        form = .submitting

        let submission = DiningRatingSubmission(
            overall: overall,
            taste: draftTaste,
            value: draftValue,
            quality: draftQuality
        )

        do {
            let result = try await service.submit(submission, venueKey: venueKey)

            // The server's aggregate is authoritative — never increment a count
            // locally, because an update must not add a vote and only the
            // server knows which case this was.
            if let aggregate = result.aggregate {
                load = aggregate.hasRatings ? .rated(aggregate) : .zero
            }
            myRating = result.rating
            // Captured from the response before any state is replaced, so a
            // first rating can never be announced as an update.
            form = .success(result.outcome)
        } catch {
            // Selections are deliberately left intact so retry is one tap.
            form = .failure
        }
    }
}
