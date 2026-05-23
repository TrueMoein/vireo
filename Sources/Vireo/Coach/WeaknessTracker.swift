// WeaknessTracker.swift — promotes recurring mistakes to weakness items.
//
// Rule: a (category, rule) tuple seen ≥ 3 times in distinct sessions becomes
// an active WeaknessItem and enters the FSRS review queue. 30 correct uses
// of the corrected form in real writing demotes it to "passive."
//
// TODO: implement in Phase 5.

import Foundation
