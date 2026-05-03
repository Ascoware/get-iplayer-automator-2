//
//  LegacyModels.swift
//  Get iPlayer Automator 2
//
//  Lightweight NSSecureCoding classes used solely for decoding NSKeyedArchiver
//  data from the old Get iPlayer Automator app. These mirror the old app's
//  archived class structure so we can unarchive and convert to the new models.
//

import Foundation

// MARK: - LegacySeries

/// Mirrors the old `Series` class (NSSecureCoding) for decoding `Queue.automatorqueue`.
class LegacySeries: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    var showName: String?
    var added: NSNumber?
    var tvNetwork: String?
    var lastFound: Date?

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        showName = coder.decodeObject(forKey: "showName") as? String
        added = coder.decodeObject(forKey: "added") as? NSNumber
        tvNetwork = coder.decodeObject(forKey: "tvNetwork") as? String
        lastFound = coder.decodeObject(forKey: "lastFound") as? Date
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(showName, forKey: "showName")
        coder.encode(added, forKey: "added")
        coder.encode(tvNetwork, forKey: "tvNetwork")
        coder.encode(lastFound, forKey: "lastFound")
    }

    func toNewSeries() -> Series {
        Series(
            showName: showName ?? "",
            added: added?.intValue ?? Int(Date().timeIntervalSince1970),
            tvNetwork: tvNetwork ?? "*",
            lastFound: lastFound ?? Date()
        )
    }
}

// MARK: - LegacyProgramme

/// Mirrors the old `Programme` class (NSSecureCoding) for decoding `Queue.automatorqueue`.
class LegacyProgramme: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    var showName: String = ""
    var episodeName: String = ""
    var pid: String = ""
    var tvNetwork: String = ""
    var status: String = ""
    var complete: Bool = false
    var successful: Bool = false
    var radio: Bool = false
    var path: String = ""
    var season: Int = 0
    var episode: Int = 0
    var processedPID: Bool = false
    var realPID: String = ""
    var subtitlePath: String = ""
    var desc: String = ""
    var duration: Int = 0
    var url: String = ""
    var addedByPVR: Bool = false
    var timeadded: NSNumber = 0
    var firstBroadcast: Date?
    var lastBroadcast: Date?
    var thumbnailURLString: String = ""

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        showName = coder.decodeObject(forKey: "showName") as? String ?? ""
        episodeName = coder.decodeObject(forKey: "episodeName") as? String ?? ""
        pid = coder.decodeObject(forKey: "pid") as? String ?? ""
        tvNetwork = coder.decodeObject(forKey: "tvNetwork") as? String ?? ""
        status = coder.decodeObject(forKey: "status") as? String ?? ""
        complete = coder.decodeBool(forKey: "complete")
        successful = coder.decodeBool(forKey: "successful")
        radio = coder.decodeBool(forKey: "radio")
        path = coder.decodeObject(forKey: "path") as? String ?? ""
        season = coder.decodeInteger(forKey: "season")
        episode = coder.decodeInteger(forKey: "episode")
        processedPID = coder.decodeBool(forKey: "processedPID")
        realPID = coder.decodeObject(forKey: "realPID") as? String ?? ""
        subtitlePath = coder.decodeObject(forKey: "subtitlePath") as? String ?? ""
        desc = coder.decodeObject(forKey: "desc") as? String ?? ""
        duration = coder.decodeInteger(forKey: "duration")
        url = coder.decodeObject(forKey: "url") as? String ?? ""
        addedByPVR = coder.decodeBool(forKey: "addedByPVR")
        timeadded = coder.decodeObject(forKey: "timeadded") as? NSNumber ?? 0
        firstBroadcast = coder.decodeObject(forKey: "firstBroadcast") as? Date
        lastBroadcast = coder.decodeObject(forKey: "lastBroadcast") as? Date
        thumbnailURLString = coder.decodeObject(forKey: "thumbnailURLString") as? String ?? ""
        super.init()
    }

    func encode(with coder: NSCoder) {
        // Encoding is not needed; these classes are only used for decoding.
    }

    @MainActor
    func toNewProgramme() -> Programme {
        let p = Programme()
        p.name = showName
        p.episode = episodeName
        p.pid = pid
        p.channel = tvNetwork
        p.seriesNum = season
        p.episodeNum = episode
        p.downloadPath = path
        p.subtitlePath = subtitlePath
        p.desc = desc
        p.duration = duration
        p.radio = radio
        p.realPID = realPID
        p.complete = complete

        // Determine programme type
        if radio {
            p.type = .radio
        } else if tvNetwork.hasPrefix("ITV") || tvNetwork.hasPrefix("STV") {
            p.type = .stv
        } else {
            p.type = .tv
        }

        // Map string status to ProgramState
        if addedByPVR {
            p.status = .addedByPVR
        } else if successful {
            p.status = .successful
        } else if status.hasPrefix("Failed") {
            p.status = .failed
        } else if status == "Cancelled" || status == "Cancelled by user" {
            p.status = .cancelled
        } else if processedPID {
            p.status = .processedPID
        } else {
            p.status = .new
        }

        // Map URLs
        if !url.isEmpty {
            p.web = URL(string: url)
        }
        if !thumbnailURLString.isEmpty {
            p.thumbnail = URL(string: thumbnailURLString)
        }

        // Map dates
        p.available = firstBroadcast ?? lastBroadcast ?? Date()
        if timeadded.doubleValue > 0 {
            p.timeadded = Date(timeIntervalSince1970: timeadded.doubleValue)
        }

        return p
    }
}

// MARK: - LegacyTVFormat

/// Mirrors the old `TVFormat` class for decoding `Formats.automatorqueue`.
class LegacyTVFormat: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    var format: String = ""

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        format = coder.decodeObject(forKey: "format") as? String ?? ""
        super.init()
    }

    func encode(with coder: NSCoder) {}

    func toNewFormat() -> TVFormat? {
        // Handle both current and legacy format names from the old app
        switch format {
        case "Full HD (1080p)":
            return .fhd
        case "HD (720p)", "Best":
            return .hd
        case "SD (540p)", "SD (576p)", "Better", "Very Good":
            return .sd
        case "Web (396p)", "Web (432p)", "Good":
            return .web
        case "Mobile (288p)", "Worst":
            return .mobile
        default:
            return nil
        }
    }
}

// MARK: - LegacyRadioFormat

/// Mirrors the old `RadioFormat` class for decoding `Formats.automatorqueue`.
class LegacyRadioFormat: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    var format: String = ""

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        format = coder.decodeObject(forKey: "format") as? String ?? ""
        super.init()
    }

    func encode(with coder: NSCoder) {}

    func toNewFormat() -> RadioFormat? {
        switch format {
        case "High", "Best":
            return .high
        case "Standard", "Better", "Very Good":
            return .standard
        case "Medium", "Good":
            return .medium
        case "Low", "Worst":
            return .low
        default:
            return nil
        }
    }
}
