//
//  FeatureFlags.swift
//  solyn
//

import Foundation

/// Features that are built but not currently offered.
///
/// Flags rather than deletions, for things we may want back. The cost of a
/// dead-but-reachable code path is a compile; the cost of deleting a feature
/// and re-deriving it later is much higher, and the git history is a worse
/// place to keep a working implementation than a `false`.
enum FeatureFlags {

    /// Attaching photos to an entry.
    ///
    /// Off since v1.11: DailyVox is a *voice* journal, and in practice the
    /// attachment did not earn the space it took — a picker beside the record
    /// button on the one screen whose job is to get you talking within a few
    /// seconds. Turned back on, every path still works: existing photos are
    /// still displayed and still export, so nobody's attachments are hidden by
    /// this being false. Only the controls that ADD new ones are withheld.
    ///
    /// NOT the same thing as `AmbientSignalManager.photoSignalsEnabled`, which
    /// reads on-device photo *labels* for the Twin and never stores an image.
    /// That is a separate feature with its own consent, and it is untouched.
    static let photoAttachments = false
}
