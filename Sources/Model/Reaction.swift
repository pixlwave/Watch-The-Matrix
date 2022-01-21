import Matrix
import CoreData

extension Reaction {
    //
}

/// A reaction with a count and optional event ID for the current user.
struct AggregatedReaction {
    /// The reaction's content
    let key: String
    /// The number of events sent for this reaction
    let count: Int
    /// If the aggregation contains an event from the current user, this is that event's ID.
    let eventIDToRedact: String?
}
