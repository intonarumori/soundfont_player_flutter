class MidiSource {
    private var midiClient: MIDIClientRef = 0
    private(set) var endpoint = MIDIEndpointRef()
    
    var callback: (([UInt8]) -> Void)?

    init() {
        let name = "soundfont midi"

        MIDIClientCreate("MyMIDIClient" as CFString, nil, nil, &midiClient)

        let cfName = name as CFString
        let status = MIDIDestinationCreateWithBlock(midiClient, cfName, &endpoint) { packetList, _ in
            withUnsafePointer(to: packetList.pointee.packet) { packetPtr in
                let ptr = UnsafeMutablePointer<MIDIPacket>.allocate(capacity:1)
                ptr.initialize(to: packetPtr.pointee)
                var packet = ptr
                let count = packetPtr.pointee.length
                
                for _ in 0..<count {
                    
                    let data = Array<UInt8>(mirrorChildValuesOf: packet.pointee.data)!
                    var i = 0
                    while (i < packet.pointee.length) {
                        if (Int(packet.pointee.length) - i >= 3) {
                            let d = Array(data[i..<i+3])
                            DispatchQueue.main.async {
                                self.callback?(d)
                            }
                            i += 3
                        } else {
                            break
                        }
                    }
                    packet = MIDIPacketNext(packet)
                }
            }
        }
        print(status == noErr)
    }
}

// MARK: -

// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

/// Sequencer based on tried-and-true CoreAudio/MIDI Sequencing
open class AppleSequencer: NSObject {
    /// Music sequence
    open var sequence: MusicSequence?

    /// Pointer to Music Sequence
    open var sequencePointer: UnsafeMutablePointer<MusicSequence>?

    /// Array of AudioKit Music Tracks
    open var tracks = [MusicTrackManager]()

    /// Music Player
    var musicPlayer: MusicPlayer?

    /// Loop control
    open private(set) var loopEnabled: Bool = false

    /// Sequencer Initialization
    override public init() {
        NewMusicSequence(&sequence)
        if let existingSequence = sequence {
            sequencePointer = UnsafeMutablePointer<MusicSequence>(existingSequence)
        }
        // setup and attach to musicplayer
        NewMusicPlayer(&musicPlayer)
        if let existingMusicPlayer = musicPlayer {
            MusicPlayerSetSequence(existingMusicPlayer, sequence)
        }
    }

    deinit {
        ////Log("deinit:")

        if let player = musicPlayer {
            DisposeMusicPlayer(player)
        }

        if let seq = sequence {
            for track in self.tracks {
                if let intTrack = track.internalMusicTrack {
                    MusicSequenceDisposeTrack(seq, intTrack)
                }
            }

            DisposeMusicSequence(seq)
        }
    }

    /// Initialize the sequence with a MIDI file
    ///
    /// - parameter filename: Location of the MIDI File
    ///
    public convenience init(filename: String) {
        self.init()
        loadMIDIFile(filename)
    }

    /// Initialize the sequence with a MIDI file
    /// - Parameter fileURL: URL of MIDI File
    public convenience init(fromURL fileURL: URL) {
        self.init()
        loadMIDIFile(fromURL: fileURL)
    }

    /// Initialize the sequence with a MIDI file data representation
    ///
    /// - parameter fromData: Data representation of a MIDI file
    ///
    public convenience init(fromData data: Data) {
        self.init()
        loadMIDIFile(fromData: data)
    }

    /// Preroll the music player. Call this function in advance of playback to reduce the sequencers
    /// startup latency. If you call `play` without first calling this function, the sequencer will
    /// call this function before beginning playback.
    public func preroll() {
        if let existingMusicPlayer = musicPlayer {
            MusicPlayerPreroll(existingMusicPlayer)
        }
    }

    // MARK: - Looping

    /// Set loop functionality of entire sequence
    public func toggleLoop() {
        loopEnabled ? disableLooping() : enableLooping()
    }

    /// Enable looping for all tracks - loops entire sequence
    public func enableLooping() {
        setLoopInfo(length, loopCount: 0)
        loopEnabled = true
    }

    /// Enable looping for all tracks with specified length
    ///
    /// - parameter loopLength: Loop length in beats
    ///
    public func enableLooping(_ loopLength: Duration) {
        setLoopInfo(loopLength, loopCount: 0)
        loopEnabled = true
    }

    /// Disable looping for all tracks
    public func disableLooping() {
        setLoopInfo(Duration(beats: 0), loopCount: 0)
        loopEnabled = false
    }

    /// Set looping duration and count for all tracks
    ///
    /// - Parameters:
    ///   - duration: Duration of the loop in beats
    ///   - loopCount: The number of time to repeat
    ///
    public func setLoopInfo(_ duration: Duration, loopCount: Int) {
        for track in tracks {
            track.setLoopInfo(duration, loopCount: loopCount)
        }
        loopEnabled = true
    }

    // MARK: - Length

    /// Set length of all tracks
    ///
    /// - parameter length: Length of tracks in beats
    ///
    public func setLength(_ length: Duration) {
        for track in tracks {
            track.setLength(length)
        }
        let size: UInt32 = 0
        var len = length.musicTimeStamp
        var tempoTrack: MusicTrack?
        if let existingSequence = sequence {
            MusicSequenceGetTempoTrack(existingSequence, &tempoTrack)
        }
        if let existingTempoTrack = tempoTrack {
            MusicTrackSetProperty(existingTempoTrack, kSequenceTrackProperty_TrackLength, &len, size)
        }
    }

    /// Length of longest track in the sequence
    open var length: Duration {
        var length: MusicTimeStamp = 0
        var tmpLength: MusicTimeStamp = 0

        for track in tracks {
            tmpLength = track.length
            if tmpLength >= length { length = tmpLength }
        }

        return Duration(beats: length, tempo: tempo)
    }

    // MARK: - Tempo and Rate

    /// Set the rate of the sequencer
    ///
    /// - parameter rate: Set the rate relative to the tempo of the track
    ///
    public func setRate(_ rate: Double) {
        if let existingMusicPlayer = musicPlayer {
            MusicPlayerSetPlayRateScalar(existingMusicPlayer, MusicTimeStamp(rate))
        }
    }

    /// Rate relative to the default tempo (BPM) of the track
    open var rate: Double {
        var rate = MusicTimeStamp(1.0)
        if let existingMusicPlayer = musicPlayer {
            MusicPlayerGetPlayRateScalar(existingMusicPlayer, &rate)
        }
        return rate
    }

    /// Clears all existing tempo events and adds single tempo event at start
    /// Will also adjust the tempo immediately if sequence is playing when called
    public func setTempo(_ bpm: Double) {
        let constrainedTempo = max(1, bpm)

        var tempoTrack: MusicTrack?

        if let existingSequence = sequence {
            MusicSequenceGetTempoTrack(existingSequence, &tempoTrack)
        }
        if isPlaying {
            var currTime: MusicTimeStamp = 0
            if let existingMusicPlayer = musicPlayer {
                MusicPlayerGetTime(existingMusicPlayer, &currTime)
            }
            currTime = fmod(currTime, length.beats)
            if let existingTempoTrack = tempoTrack {
                MusicTrackNewExtendedTempoEvent(existingTempoTrack, currTime, constrainedTempo)
            }
        }
        if let existingTempoTrack = tempoTrack {
            MusicTrackClear(existingTempoTrack, 0, length.beats)
            clearTempoEvents(existingTempoTrack)
            MusicTrackNewExtendedTempoEvent(existingTempoTrack, 0, constrainedTempo)
        }
    }

    /// Add a  tempo change to the score
    ///
    /// - Parameters:
    ///   - bpm: Tempo in beats per minute
    ///   - position: Point in time in beats
    ///
    public func addTempoEventAt(tempo bpm: Double, position: Duration) {
        let constrainedTempo = max(1, bpm)

        var tempoTrack: MusicTrack?

        if let existingSequence = sequence {
            MusicSequenceGetTempoTrack(existingSequence, &tempoTrack)
        }
        if let existingTempoTrack = tempoTrack {
            MusicTrackNewExtendedTempoEvent(existingTempoTrack, position.beats, constrainedTempo)
        }
    }

    /// Tempo retrieved from the sequencer. Defaults to 120
    /// NB: It looks at the currentPosition back in time for the last tempo event.
    /// If the sequence is not started, it returns default 120
    /// A sequence may contain several tempo events.
    open var tempo: Double {
        var tempoOut = 120.0

        var tempoTrack: MusicTrack?
        if let existingSequence = sequence {
            MusicSequenceGetTempoTrack(existingSequence, &tempoTrack)
        }

        var tempIterator: MusicEventIterator?
        if let existingTempoTrack = tempoTrack {
            NewMusicEventIterator(existingTempoTrack, &tempIterator)
        }
        guard let iterator = tempIterator else {
            return 0.0
        }

        var eventTime: MusicTimeStamp = 0
        var eventType: MusicEventType = kMusicEventType_ExtendedTempo
        var eventData: UnsafeRawPointer?
        var eventDataSize: UInt32 = 0

        var hasPreviousEvent: DarwinBoolean = false
        MusicEventIteratorSeek(iterator, currentPosition.beats)
        MusicEventIteratorHasPreviousEvent(iterator, &hasPreviousEvent)
        if hasPreviousEvent.boolValue {
            MusicEventIteratorPreviousEvent(iterator)
            MusicEventIteratorGetEventInfo(iterator, &eventTime, &eventType, &eventData, &eventDataSize)
            if eventType == kMusicEventType_ExtendedTempo {
                if let data = eventData?.bindMemory(to: ExtendedTempoEvent.self, capacity: 1) {
                    tempoOut = data.pointee.bpm
                }
            }
        }
        DisposeMusicEventIterator(iterator)
        return tempoOut
    }

    /// returns an array of (MusicTimeStamp, bpm) tuples
    /// for all tempo events on the tempo track
    open var allTempoEvents: [(MusicTimeStamp, Double)] {
        var tempoTrack: MusicTrack?
        guard let existingSequence = sequence else { return [] }
        MusicSequenceGetTempoTrack(existingSequence, &tempoTrack)

        var tempos = [(MusicTimeStamp, Double)]()

        if let tempoTrack = tempoTrack {
            MusicTrackManager.iterateMusicTrack(tempoTrack) { _, eventTime, eventType, eventData, _, _ in
                if eventType == kMusicEventType_ExtendedTempo {
                    if let data = eventData?.bindMemory(to: ExtendedTempoEvent.self, capacity: 1) {
                        tempos.append((eventTime, data.pointee.bpm))
                    }
                }
            }
        }
        return tempos
    }

    /// returns the tempo at a given position in beats
    /// - parameter at: Position at which the tempo is desired
    ///
    /// if there is more than one event precisely at the requested position
    /// it will return the most recently added
    /// Will return default 120 if there is no tempo event at or before position
    public func getTempo(at position: MusicTimeStamp) -> Double {
        // MIDI file with no tempo events defaults to 120 bpm
        var tempoAtPosition = 120.0
        for event in allTempoEvents {
            if event.0 <= position {
                tempoAtPosition = event.1
            } else {
                break
            }
        }

        return tempoAtPosition
    }

    // Remove existing tempo events
    func clearTempoEvents(_ track: MusicTrack) {
        MusicTrackManager.iterateMusicTrack(track) { iterator, _, eventType, _, _, isReadyForNextEvent in
            isReadyForNextEvent = true
            if eventType == kMusicEventType_ExtendedTempo {
                MusicEventIteratorDeleteEvent(iterator)
                isReadyForNextEvent = false
            }
        }
    }

    // MARK: - Time Signature

    /// Return and array of (MusicTimeStamp, TimeSignature) tuples
//    open var allTimeSignatureEvents: [(MusicTimeStamp, TimeSignature)] {
//        var tempoTrack: MusicTrack?
//        var result = [(MusicTimeStamp, TimeSignature)]()
//
//        if let existingSequence = sequence {
//            MusicSequenceGetTempoTrack(existingSequence, &tempoTrack)
//        }
//
//        guard let unwrappedTempoTrack = tempoTrack else {
//            ////Log("Couldn't get tempo track")
//            return result
//        }
//
//        let timeSignatureMetaEventByte: MIDIByte = 0x58
//        MusicTrackManager.iterateMusicTrack(unwrappedTempoTrack) { _, eventTime, eventType, eventData, dataSize, _ in
//            guard let eventData = eventData else { return }
//            guard eventType == kMusicEventType_Meta else { return }
//
//            let metaEventPointer = UnsafeMIDIMetaEventPointer(eventData)
//            let metaEvent = metaEventPointer.event.pointee
//            if metaEvent.metaEventType == timeSignatureMetaEventByte {
//                let rawTimeSig = metaEventPointer.payload
//                guard let bottomValue = TimeSignature.TimeSignatureBottomValue(rawValue: rawTimeSig[1]) else {
//                    ////Log("Invalid time signature bottom value")
//                    return
//                }
//                let timeSigEvent = TimeSignature(topValue: rawTimeSig[0],
//                                                 bottomValue: bottomValue)
//                result.append((eventTime, timeSigEvent))
//            }
//        }
//
//        return result
//    }

    /// returns the time signature at a given position in beats
    /// - parameter at: Position at which the time signature is desired
    ///
    /// If there is more than one event precisely at the requested position
    /// it will return the most recently added.
    /// Will return 4/4 if there is no Time Signature event at or before position
//    public func getTimeSignature(at position: MusicTimeStamp) -> TimeSignature {
//        var outTimeSignature = TimeSignature() // 4/4, by default
//        for event in allTimeSignatureEvents {
//            if event.0 <= position {
//                outTimeSignature = event.1
//            } else {
//                break
//            }
//        }
//
//        return outTimeSignature
//    }

    /// Remove existing time signature events from tempo track
    func clearTimeSignatureEvents(_ track: MusicTrack) {
//        let timeSignatureMetaEventByte: MIDIByte = 0x58
//        let metaEventType = kMusicEventType_Meta
//
//        MusicTrackManager.iterateMusicTrack(track) { iterator, _, eventType, eventData, _, isReadyForNextEvent in
//            isReadyForNextEvent = true
//            guard eventType == metaEventType else { return }
//
//            let data = eventData?.bindMemory(to: MIDIMetaEvent.self, capacity: 1)
//            guard let dataMetaEventType = data?.pointee.metaEventType else { return }
//
//            if dataMetaEventType == timeSignatureMetaEventByte {
//                MusicEventIteratorDeleteEvent(iterator)
//                isReadyForNextEvent = false
//            }
//        }
    }

    // MARK: - Duration

    /// Convert seconds into Duration
    ///
    /// - parameter seconds: time in seconds
    ///
    public func duration(seconds: Double) -> Duration {
        let sign = seconds > 0 ? 1.0 : -1.0
        let absoluteValueSeconds = fabs(seconds)
        var outBeats = Duration(beats: MusicTimeStamp())
        if let existingSequence = sequence {
            MusicSequenceGetBeatsForSeconds(existingSequence, Float64(absoluteValueSeconds), &outBeats.beats)
        }
        outBeats.beats *= sign
        return outBeats
    }

    /// Convert beats into seconds
    ///
    /// - parameter duration: Duration
    ///
    public func seconds(duration: Duration) -> Double {
        let sign = duration.beats > 0 ? 1.0 : -1.0
        let absoluteValueBeats = fabs(duration.beats)
        var outSecs: Double = MusicTimeStamp()
        if let existingSequence = sequence {
            MusicSequenceGetSecondsForBeats(existingSequence, absoluteValueBeats, &outSecs)
        }
        outSecs *= sign
        return outSecs
    }

    // MARK: - Transport Control

    /// Play the sequence
    public func play() {
        if let existingMusicPlayer = musicPlayer {
            MusicPlayerStart(existingMusicPlayer)
        }
    }

    /// Stop the sequence
    public func stop() {
        if let existingMusicPlayer = musicPlayer {
            MusicPlayerStop(existingMusicPlayer)
        }
    }

    /// Rewind the sequence
    public func rewind() {
        if let existingMusicPlayer = musicPlayer {
            MusicPlayerSetTime(existingMusicPlayer, 0)
        }
    }

    /// Whether or not the sequencer is currently playing
    open var isPlaying: Bool {
        var isPlayingBool: DarwinBoolean = false
        if let existingMusicPlayer = musicPlayer {
            MusicPlayerIsPlaying(existingMusicPlayer, &isPlayingBool)
        }
        return isPlayingBool.boolValue
    }

    /// Current Time
    open var currentPosition: Duration {
        var currentTime = MusicTimeStamp()
        if let existingMusicPlayer = musicPlayer {
            MusicPlayerGetTime(existingMusicPlayer, &currentTime)
        }
        let duration = Duration(beats: currentTime)
        return duration
    }

    /// Current Time relative to sequencer length
    open var currentRelativePosition: Duration {
        return currentPosition % length // can switch to modTime func when/if % is removed
    }

    // MARK: - Other Sequence Properties

    /// Track count
    open var trackCount: Int {
        var count: UInt32 = 0
        if let existingSequence = sequence {
            MusicSequenceGetTrackCount(existingSequence, &count)
        }
        return Int(count)
    }

    /// Time Resolution, i.e., Pulses per quarter note
    open var timeResolution: UInt32 {
        let failedValue: UInt32 = 0
        guard let existingSequence = sequence else {
            ////Log("Couldn't get sequence for time resolution")
            return failedValue
        }
        var tempoTrack: MusicTrack?
        MusicSequenceGetTempoTrack(existingSequence, &tempoTrack)

        guard let unwrappedTempoTrack = tempoTrack else {
            ////Log("No tempo track for time resolution")
            return failedValue
        }

        var ppqn: UInt32 = 0
        var propertyLength: UInt32 = 0

        MusicTrackGetProperty(unwrappedTempoTrack,
                              kSequenceTrackProperty_TimeResolution,
                              &ppqn,
                              &propertyLength)

        return ppqn
    }

    // MARK: - Loading MIDI files

    /// Load a MIDI file from the bundle (removes old tracks, if present)
    public func loadMIDIFile(_ filename: String) {
        let bundle = Bundle.main
        guard let file = bundle.path(forResource: filename, ofType: "mid") else {
            ////Log("No midi file found")
            return
        }
        let fileURL = URL(fileURLWithPath: file)
        loadMIDIFile(fromURL: fileURL)
    }

    /// Load a MIDI file given a URL (removes old tracks, if present)
    public func loadMIDIFile(fromURL fileURL: URL) {
        removeTracks()
        if let existingSequence = sequence {
            let status: OSStatus = MusicSequenceFileLoad(existingSequence,
                                                         fileURL as CFURL,
                                                         .midiType,
                                                         MusicSequenceLoadFlags())
            if status != OSStatus(noErr) {
                ////Log("error reading midi file url: \(fileURL), read status: \(status)")
            }
        }
        initTracks()
    }

    /// Load a MIDI file given its data representation (removes old tracks, if present)
    public func loadMIDIFile(fromData data: Data) {
        removeTracks()
        if let existingSequence = sequence {
            let status: OSStatus = MusicSequenceFileLoadData(existingSequence,
                                                             data as CFData,
                                                             .midiType,
                                                             MusicSequenceLoadFlags())
            if status != OSStatus(noErr) {
                ////Log("error reading midi data, read status: \(status)")
            }
        }
        initTracks()
    }

    // MARK: - Adding MIDI File data to current sequencer

    /// Add tracks from MIDI file to existing sequencer
    ///
    /// - Parameters:
    ///   - filename: Location of the MIDI File
    ///   - useExistingSequencerLength: flag for automatically setting length of new track to current sequence length
    ///
    ///  Will copy only MIDINoteMessage events
    public func addMIDIFileTracks(_ filename: String, useExistingSequencerLength: Bool = true) {
        let tempSequencer = AppleSequencer(filename: filename)
        addMusicTrackNoteData(from: tempSequencer, useExistingSequencerLength: useExistingSequencerLength)
    }

    /// Add tracks from MIDI file to existing sequencer
    ///
    /// - Parameters:
    ///   - filename: fromURL: URL of MIDI File
    ///   - useExistingSequencerLength: flag for automatically setting length of new track to current sequence length
    ///
    ///  Will copy only MIDINoteMessage events
    public func addMIDIFileTracks(_ url: URL, useExistingSequencerLength: Bool = true) {
        let tempSequencer = AppleSequencer(fromURL: url)
        addMusicTrackNoteData(from: tempSequencer, useExistingSequencerLength: useExistingSequencerLength)
    }

    /// Creates new MusicTrackManager with copied note event data from another AppleSequencer
    func addMusicTrackNoteData(from tempSequencer: AppleSequencer, useExistingSequencerLength: Bool) {
        guard !isPlaying else {
            ////Log("Can't add tracks during playback")
            return
        }

        let oldLength = length
        for track in tempSequencer.tracks {
            let noteData = track.getMIDINoteData()

            if noteData.isEmpty { continue }
            let addedTrack = newTrack()

            addedTrack?.replaceMIDINoteData(with: noteData)

            if useExistingSequencerLength {
                addedTrack?.setLength(oldLength)
            }
        }

        if loopEnabled {
            enableLooping()
        }
    }

    /// Initialize all tracks
    ///
    /// Rebuilds tracks based on actual contents of music sequence
    ///
    func initTracks() {
        var count: UInt32 = 0
        if let existingSequence = sequence {
            MusicSequenceGetTrackCount(existingSequence, &count)
        }

        for i in 0 ..< count {
            var musicTrack: MusicTrack?
            if let existingSequence = sequence {
                MusicSequenceGetIndTrack(existingSequence, UInt32(i), &musicTrack)
            }
            if let existingMusicTrack = musicTrack {
                tracks.append(MusicTrackManager(musicTrack: existingMusicTrack, name: ""))
            }
        }

        if loopEnabled {
            enableLooping()
        }
    }

    ///  Dispose of tracks associated with sequence
    func removeTracks() {
        if let existingSequence = sequence {
            var tempoTrack: MusicTrack?
            MusicSequenceGetTempoTrack(existingSequence, &tempoTrack)
            if let track = tempoTrack {
                MusicTrackClear(track, 0, length.musicTimeStamp)
                clearTimeSignatureEvents(track)
                clearTempoEvents(track)
            }

            for track in tracks {
                if let internalTrack = track.internalMusicTrack {
                    MusicSequenceDisposeTrack(existingSequence, internalTrack)
                }
            }
        }
        tracks.removeAll()
    }

    /// Get a new track
    public func newTrack(_ name: String = "Unnamed") -> MusicTrackManager? {
        guard let existingSequence = sequence else { return nil }
        var newMusicTrack: MusicTrack?
        MusicSequenceNewTrack(existingSequence, &newMusicTrack)
        guard let musicTrack = newMusicTrack else { return nil }
        let newTrack = MusicTrackManager(musicTrack: musicTrack, name: name)
        tracks.append(newTrack)
        return newTrack
    }

    // MARK: - Delete Tracks

    /// Delete track and remove it from the sequence
    /// Not to be used during playback
    public func deleteTrack(trackIndex: Int) {
        guard !isPlaying else {
            ////Log("Can't delete sequencer track during playback")
            return
        }
        guard trackIndex < tracks.count,
              let internalTrack = tracks[trackIndex].internalMusicTrack
        else {
            ////Log("Can't get track for index")
            return
        }

        guard let existingSequence = sequence else {
            ////Log("Can't get sequence")
            return
        }

        MusicSequenceDisposeTrack(existingSequence, internalTrack)
        tracks.remove(at: trackIndex)
    }

    /// Clear all non-tempo events from all tracks within the specified range
    //
    /// - Parameters:
    ///   - start: Start of the range to clear, in beats (inclusive)
    ///   - duration: Length of time after the start position to clear, in beats (exclusive)
    ///
    public func clearRange(start: Duration, duration: Duration) {
        for track in tracks {
            track.clearRange(start: start, duration: duration)
        }
    }

    /// Set the music player time directly
    ///
    /// - parameter time: Music time stamp to set
    ///
    public func setTime(_ time: MusicTimeStamp) {
        if let existingMusicPlayer = musicPlayer {
            MusicPlayerSetTime(existingMusicPlayer, time)
        }
    }

    /// Generate NSData from the sequence
    public func genData() -> Data? {
        var status = noErr
        var ns = Data()
        var data: Unmanaged<CFData>?
        if let existingSequence = sequence {
            status = MusicSequenceFileCreateData(existingSequence, .midiType, .eraseFile, 480, &data)

            if status != noErr {
                ////Log("error creating MusicSequence Data")
                return nil
            }
        }
        if let existingData = data {
            ns = existingData.takeUnretainedValue() as Data
        }
        data?.release()
        return ns
    }

    /// Print sequence to console
    public func debug() {
        if let existingPointer = sequencePointer {
            CAShow(existingPointer)
        }
    }

    /// Set the midi output for all tracks
    @available(tvOS 12.0, *)
    public func setGlobalMIDIOutput(_ midiEndpoint: MIDIEndpointRef) {
        for track in tracks {
            track.setMIDIOutput(midiEndpoint)
        }
    }

    /// Nearest time of quantized beat
    public func nearestQuantizedPosition(quantizationInBeats: Double) -> Duration {
        let noteOnTimeRel = currentRelativePosition.beats
        let quantizationPositions = getQuantizationPositions(quantizationInBeats: quantizationInBeats)
        let lastSpot = quantizationPositions[0]
        let nextSpot = quantizationPositions[1]
        let diffToLastSpot = Duration(beats: noteOnTimeRel) - lastSpot
        let diffToNextSpot = nextSpot - Duration(beats: noteOnTimeRel)
        let optimisedQuantTime = (diffToLastSpot < diffToNextSpot ? lastSpot : nextSpot)
        return optimisedQuantTime
    }

    /// The last quantized beat
    public func previousQuantizedPosition(quantizationInBeats: Double) -> Duration {
        return getQuantizationPositions(quantizationInBeats: quantizationInBeats)[0]
    }

    /// Next quantized beat
    public func nextQuantizedPosition(quantizationInBeats: Double) -> Duration {
        return getQuantizationPositions(quantizationInBeats: quantizationInBeats)[1]
    }

    /// An array of all quantization points
    func getQuantizationPositions(quantizationInBeats: Double) -> [Duration] {
        let noteOnTimeRel = currentRelativePosition.beats
        let lastSpot = Duration(beats:
            modTime(noteOnTimeRel - noteOnTimeRel.truncatingRemainder(dividingBy: quantizationInBeats)))
        let nextSpot = Duration(beats: modTime(lastSpot.beats + quantizationInBeats))
        return [lastSpot, nextSpot]
    }

    /// Time modulus
    func modTime(_ time: Double) -> Double {
        return time.truncatingRemainder(dividingBy: length.beats)
    }

    // MARK: - Time Conversion

    public enum MusicPlayerTimeConversionError: Error {
        case musicPlayerIsNotPlaying
        case osStatus(OSStatus)
    }

    /// Returns the host time that will be (or was) played at the specified beat.
    /// This function is valid only if the music player is playing.
    public func hostTime(forBeats inBeats: AVMusicTimeStamp) throws -> UInt64 {
        guard let musicPlayer = musicPlayer, isPlaying else {
            throw MusicPlayerTimeConversionError.musicPlayerIsNotPlaying
        }
        var hostTime: UInt64 = 0
        let code = MusicPlayerGetHostTimeForBeats(musicPlayer, inBeats, &hostTime)
        guard code == noErr else {
            throw MusicPlayerTimeConversionError.osStatus(code)
        }
        return hostTime
    }

    /// Returns the beat that will be (or was) played at the specified host time.
    /// This function is valid only if the music player is playing.
    public func beats(forHostTime inHostTime: UInt64) throws -> AVMusicTimeStamp {
        guard let musicPlayer = musicPlayer, isPlaying else {
            throw MusicPlayerTimeConversionError.musicPlayerIsNotPlaying
        }
        var beats: MusicTimeStamp = 0
        let code = MusicPlayerGetBeatsForHostTime(musicPlayer, inHostTime, &beats)
        guard code == noErr else {
            throw MusicPlayerTimeConversionError.osStatus(code)
        }
        return beats
    }
}



// MARK: -

public typealias BPM = Double

/// Container for the notion of time in sequencing
public struct Duration: CustomStringConvertible, Comparable {
    static let secondsPerMinute = 60

    /// Duration in beats
    public var beats: Double

    /// Samples per second
    public var sampleRate: Double = 44100 //Settings.sampleRate

    /// Tempo in BPM (beats per minute)
    public var tempo: BPM = 60.0

    /// While samples is the most accurate, they blow up too fast, so using beat as standard
    public var samples: Int {
        get {
            let doubleSamples = beats / tempo * Double(Duration.secondsPerMinute) * sampleRate
            if doubleSamples <= Double(Int.max) {
                return Int(doubleSamples)
            } else {
                //////Log("Warning: Samples exceeds the maximum number.")
                return .max
            }
        }
        set {
            beats = (Double(newValue) / Double(sampleRate)) / Double(Duration.secondsPerMinute) * tempo
        }
    }

    /// Regular time measurement
    public var seconds: Double {
        return Double(samples) / sampleRate
    }

    /// Useful for math using tempo in BPM (beats per minute)
    public var minutes: Double {
        return seconds / 60.0
    }

    /// Music time stamp for the duration in beats
    public var musicTimeStamp: MusicTimeStamp {
        return MusicTimeStamp(beats)
    }

    /// Pretty printout
    public var description: String {
        return "\(samples) samples at \(sampleRate) = \(beats) Beats at \(tempo) BPM = \(seconds)s"
    }

    /// Initialize with samples
    ///
    /// - Parameters:
    ///   - samples:    Number of samples
    ///   - sampleRate: Sample rate in samples per second
    ///
    public init(samples: Int, sampleRate: Double = 44100, tempo: BPM = 60) {
        beats = tempo * (Double(samples) / sampleRate) / Double(Duration.secondsPerMinute)
        self.sampleRate = sampleRate
        self.tempo = tempo
    }

    /// Initialize from a beat perspective
    ///
    /// - Parameters:
    ///   - beats: Duration in beats
    ///   - tempo: Durations per minute
    ///
    public init(beats: Double, tempo: BPM = 60) {
        self.beats = beats
        self.tempo = tempo
    }

    /// Initialize from a normal time perspective
    ///
    /// - Parameters:
    ///   - seconds:    Duration in seconds
    ///   - sampleRate: Samples per second
    ///
    public init(seconds: Double, sampleRate: Double = 44100, tempo: BPM = 60) {
        self.sampleRate = sampleRate
        self.tempo = tempo
        beats = tempo * (seconds / Double(Duration.secondsPerMinute))
    }

    /// Add to a duration
    ///
    /// - parameter lhs: Starting duration
    /// - parameter rhs: Amount to add
    ///
    public static func += (lhs: inout Duration, rhs: Duration) {
        lhs.beats += rhs.beats
    }

    /// Subtract from a duration
    ///
    /// - parameter lhs: Starting duration
    /// - parameter rhs: Amount to subtract
    ///
    public static func -= (lhs: inout Duration, rhs: Duration) {
        lhs.beats -= rhs.beats
    }

    /// Duration equality
    ///
    /// - parameter lhs: One duration
    /// - parameter rhs: Another duration
    ///
    public static func == (lhs: Duration, rhs: Duration) -> Bool {
        return lhs.beats == rhs.beats
    }

    /// Duration less than
    ///
    /// - parameter lhs: One duration
    /// - parameter rhs: Another duration
    ///
    public static func < (lhs: Duration, rhs: Duration) -> Bool {
        return lhs.beats < rhs.beats
    }

    /// Adding durations
    ///
    /// - parameter lhs: One duration
    /// - parameter rhs: Another duration
    ///
    public static func + (lhs: Duration, rhs: Duration) -> Duration {
        var newDuration = lhs
        newDuration.beats += rhs.beats
        return newDuration
    }

    /// Subtracting durations
    ///
    /// - parameter lhs: One duration
    /// - parameter rhs: Another duration
    ///
    public static func - (lhs: Duration, rhs: Duration) -> Duration {
        var newDuration = lhs
        newDuration.beats -= rhs.beats
        return newDuration
    }

    /// Modulus of the duration's beats
    ///
    /// - parameter lhs: One duration
    /// - parameter rhs: Another duration
    ///
    public static func % (lhs: Duration, rhs: Duration) -> Duration {
        var copy = lhs
        copy.beats = lhs.beats.truncatingRemainder(dividingBy: rhs.beats)
        return copy
    }
}

// MARK: -

import AVFoundation

public typealias MIDIByte = UInt8
/// MIDI Type Alias making it clear that you're working with MIDI
public typealias MIDIWord = UInt16
/// MIDI Type Alias making it clear that you're working with MIDI
public typealias MIDINoteNumber = UInt8
/// MIDI Type Alias making it clear that you're working with MIDI
public typealias MIDIVelocity = UInt8
/// MIDI Type Alias making it clear that you're working with MIDI
public typealias MIDIChannel = UInt8

/// Wrapper for internal Apple MusicTrack
open class MusicTrackManager {
    // MARK: - Properties

    /// The representation of Apple's underlying music track
    open var internalMusicTrack: MusicTrack?

    /// A copy of the original track at init
    open var initMusicTrack: MusicTrack?

    open var name: String = "Unnamed"

    /// Sequencer this music track is part of
    open var sequencer = AppleSequencer()

    /// Pointer to the Music Track
    open var trackPointer: UnsafeMutablePointer<MusicTrack>?
    /// Pointer to the initial music track
    open var initTrackPointer: UnsafeMutablePointer<MusicTrack>?

    /// Nicer function for not empty
    open var isNotEmpty: Bool {
        return !isEmpty
    }

    /// Total duration of the music track
    open var length: MusicTimeStamp {
        var size: UInt32 = 0
        var lengthFromMusicTimeStamp = MusicTimeStamp(0)
        if let track = internalMusicTrack {
            MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength, &lengthFromMusicTimeStamp, &size)
        }
        return lengthFromMusicTimeStamp
    }

    /// Total duration of the music track
    open var initLength: MusicTimeStamp {
        var size: UInt32 = 0
        var lengthFromMusicTimeStamp = MusicTimeStamp(0)
        if let track = initMusicTrack {
            MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength, &lengthFromMusicTimeStamp, &size)
        }
        return lengthFromMusicTimeStamp
    }

    // MARK: - Initialization

    /// Initialize with a name
    /// - Parameter name: Name of the track
    public init(name: String = "Unnamed") {
        self.name = name
        guard let seq = sequencer.sequence else { fatalError() }
        MusicSequenceNewTrack(seq, &internalMusicTrack)
        MusicSequenceNewTrack(seq, &initMusicTrack)

        if let track = internalMusicTrack {
            trackPointer = UnsafeMutablePointer(track)
        }
        if let track = initMusicTrack {
            initTrackPointer = UnsafeMutablePointer(track)
        }

        let data = [MIDIByte](name.utf8)

        let metaEventPtr = MIDIMetaEvent.allocate(metaEventType: 3, data: data)
        defer { metaEventPtr.deallocate() }

        if let track = internalMusicTrack {
            let result = MusicTrackNewMetaEvent(track, MusicTimeStamp(0), metaEventPtr)
            if result != 0 {
                //Log("Unable to name Track")
            }
        }
    }

    /// Initialize with a music track
    ///
    /// - parameter musicTrack: An Apple Music Track
    /// - parameter name: Name for the track
    ///   - if name is an empty string, the name is read from track name meta event.
    ///   - if name is not empty, that name is used and a track name meta event is added or replaced.
    ///
    public init(musicTrack: MusicTrack, name: String = "Unnamed") {
        self.name = name
        internalMusicTrack = musicTrack
        trackPointer = UnsafeMutablePointer(musicTrack)

        if name == "" {
            // Use track name from meta event (or empty name if no meta event found)
            self.name = tryReadTrackNameFromMetaEvent() ?? ""
        } else {
            // Clear track name meta event if exists
            clearMetaEvent(3)
            // Add meta event with new track name
            let data = [MIDIByte](name.utf8)
            addMetaEvent(metaEventType: 3, data: data)
        }

        initSequence()
    }

    /// Try to read existing track name from meta event
    ///
    /// - returns: the found track name or nil
    ///
    func tryReadTrackNameFromMetaEvent() -> String? {
        var trackName: String?

//        eventData?.forEach({ event in
//            if event.type == kMusicEventType_Meta {
//                let metaEventPointer = UnsafeMIDIMetaEventPointer(event.data)
//                let metaEvent = metaEventPointer!.event.pointee
//                if metaEvent.metaEventType == 0x03 {
//                    trackName = String(decoding: metaEventPointer!.payload, as: UTF8.self)
//                }
//            }
//        })
        return trackName
    }

    /// Initialize with a music track and the NoteEventSequence
    ///
    /// - parameter musicTrack: An Apple Music Track
    ///
    public init(musicTrack: MusicTrack, sequencer: AppleSequencer) {
        internalMusicTrack = musicTrack
        trackPointer = UnsafeMutablePointer(musicTrack)
        self.sequencer = sequencer
        initSequence()
    }

    private func initSequence() {
        guard let sequence = sequencer.sequence else {
            //Log("Sequence is nil")
            return
        }

        MusicSequenceNewTrack(sequence, &initMusicTrack)

        if let initMusicTrack = initMusicTrack,
           let internalMusicTrack = internalMusicTrack
        {
            initTrackPointer = UnsafeMutablePointer(initMusicTrack)
            MusicTrackMerge(internalMusicTrack, 0.0, length, initMusicTrack, 0.0)
        }
    }

    /// Set the Node Output
    ///
    /// - parameter node: Apple AUNode for output
    ///
    public func setNodeOutput(_ node: AUNode) {
        if let musicTrack = internalMusicTrack {
            MusicTrackSetDestNode(musicTrack, node)
        }
    }

    /// Set loop info
    ///
    /// - parameter duration: How long the loop will last, from the end of the track backwards
    /// - parameter loopCount: how many times to loop. 0 is infinite
    ///
    public func setLoopInfo(_ duration: Duration, loopCount: Int) {
        let size = UInt32(MemoryLayout<MusicTrackLoopInfo>.size)
        let loopDuration = duration.musicTimeStamp
        var loopInfo = MusicTrackLoopInfo(loopDuration: loopDuration,
                                          numberOfLoops: Int32(loopCount))
        if let musicTrack = internalMusicTrack {
            MusicTrackSetProperty(musicTrack, kSequenceTrackProperty_LoopInfo, &loopInfo, size)
        }
    }

    /// Set length
    /// If any of your notes are longer than the new length, this will truncate those notes
    /// This will truncate your sequence if you shorten it - so make a copy if you plan on doing that.
    ///
    /// - parameter duration: How long the loop will last, from the end of the track backwards
    ///
    public func setLength(_ duration: Duration) {
        let size: UInt32 = 0
        var durationAsMusicTimeStamp = duration.musicTimeStamp
        var tempSequence: MusicSequence?
        var tempTrack: MusicTrack?

        NewMusicSequence(&tempSequence)
        guard let newSequence = tempSequence else {
            //Log("Unable to create temp sequence in setLength")
            return
        }

        MusicSequenceNewTrack(newSequence, &tempTrack)
        guard let newTrack = tempTrack,
              let track = internalMusicTrack
        else {
            //Log("internalMusicTrack does not exist")
            return
        }
        MusicTrackSetProperty(track,
                              kSequenceTrackProperty_TrackLength,
                              &durationAsMusicTimeStamp,
                              size)

        if isNotEmpty {
            MusicTrackCopyInsert(track, 0, durationAsMusicTimeStamp, newTrack, 0)
            clear()
            MusicTrackSetProperty(track,
                                  kSequenceTrackProperty_TrackLength,
                                  &durationAsMusicTimeStamp,
                                  size)
            MusicTrackCopyInsert(newTrack, 0, durationAsMusicTimeStamp, track, 0)

            // now to clean up any notes that are too long
            var tempIterator: MusicEventIterator?
            NewMusicEventIterator(track, &tempIterator)
            guard let iterator = tempIterator else {
                //Log("Unable to create iterator in setLength")
                return
            }
            var eventTime = MusicTimeStamp(0)
            var eventType = MusicEventType()
            var eventData: UnsafeRawPointer?
            var eventDataSize: UInt32 = 0
            var hasNextEvent: DarwinBoolean = false

            MusicEventIteratorHasCurrentEvent(iterator, &hasNextEvent)

            while hasNextEvent.boolValue {
                MusicEventIteratorGetEventInfo(iterator,
                                               &eventTime,
                                               &eventType,
                                               &eventData,
                                               &eventDataSize)

                if eventType == kMusicEventType_MIDINoteMessage {
                    let data = eventData?.bindMemory(to: MIDINoteMessage.self, capacity: 1)

                    guard let channel = data?.pointee.channel,
                          let note = data?.pointee.note,
                          let velocity = data?.pointee.velocity,
                          let dur = data?.pointee.duration
                    else {
                        //Log("Problem with raw midi note message")
                        return
                    }

                    if eventTime + Double(dur) > duration.beats {
                        var newNote = MIDINoteMessage(channel: channel,
                                                      note: note,
                                                      velocity: velocity,
                                                      releaseVelocity: 0,
                                                      duration: Float32(duration.beats - eventTime))
                        MusicEventIteratorSetEventInfo(iterator, eventType, &newNote)
                    }
                }
                MusicEventIteratorNextEvent(iterator)
                MusicEventIteratorHasCurrentEvent(iterator, &hasNextEvent)
            }
            DisposeMusicEventIterator(iterator)
        } else {
            MusicTrackSetProperty(track,
                                  kSequenceTrackProperty_TrackLength,
                                  &durationAsMusicTimeStamp,
                                  size)
        }
        MusicSequenceDisposeTrack(newSequence, newTrack)
        DisposeMusicSequence(newSequence)
    }

    /// A less destructive and simpler way to set the length
    ///
    /// - parameter duration:
    ///
    public func setLengthSoft(_ duration: Duration) {
        let size: UInt32 = 0
        var durationAsMusicTimeStamp = duration.musicTimeStamp
        if let track = internalMusicTrack {
            _ = MusicTrackSetProperty(track,
                                      kSequenceTrackProperty_TrackLength,
                                      &durationAsMusicTimeStamp,
                                      size)
        }
    }

    /// Clear all events from the track
    public func clear() {
        clearMetaEvents()
        if let track = internalMusicTrack {
            if isNotEmpty {
                MusicTrackClear(track, 0, length)
            }
        }
    }

    /// Clear meta events from the track
    public func clearMetaEvents() {
        clearHelper(kMusicEventType_Meta, from: "clearMetaEvents")
    }

    /// Clear SysEx events from the track
    public func clearSysExEvents() {
        clearHelper(kMusicEventType_MIDIRawData, from: "clearSysExEvents")
    }

    private func clearHelper(_ targetEventType: UInt32, from functionName: String) {
        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return
        }
        var tempIterator: MusicEventIterator?
        NewMusicEventIterator(track, &tempIterator)
        guard let iterator = tempIterator else {
            //Log("Unable to create iterator in \(functionName)")
            return
        }
        var eventTime = MusicTimeStamp(0)
        var eventType = MusicEventType()
        var eventData: UnsafeRawPointer?
        var eventDataSize: UInt32 = 0
        var hasNextEvent: DarwinBoolean = false

        MusicEventIteratorHasCurrentEvent(iterator, &hasNextEvent)
        while hasNextEvent.boolValue {
            MusicEventIteratorGetEventInfo(iterator,
                                           &eventTime,
                                           &eventType,
                                           &eventData,
                                           &eventDataSize)

            if targetEventType == eventType {
                MusicEventIteratorDeleteEvent(iterator)
            } else {
                MusicEventIteratorNextEvent(iterator)
            }
            MusicEventIteratorHasCurrentEvent(iterator, &hasNextEvent)
        }
        DisposeMusicEventIterator(iterator)
    }

    /// Clear a specific note
    public func clearNote(_ note: MIDINoteNumber) {
        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return
        }
        var tempIterator: MusicEventIterator?
        NewMusicEventIterator(track, &tempIterator)
        guard let iterator = tempIterator else {
            //Log("Unable to create iterator in clearNote")
            return
        }
        var eventTime = MusicTimeStamp(0)
        var eventType = MusicEventType()
        var eventData: UnsafeRawPointer?
        var eventDataSize: UInt32 = 0
        var hasNextEvent: DarwinBoolean = false
        var isReadyForNextEvent: Bool

        MusicEventIteratorHasCurrentEvent(iterator, &hasNextEvent)
        while hasNextEvent.boolValue {
            isReadyForNextEvent = true
            MusicEventIteratorGetEventInfo(iterator,
                                           &eventTime,
                                           &eventType,
                                           &eventData,
                                           &eventDataSize)
            if eventType == kMusicEventType_MIDINoteMessage {
                if let convertedData = eventData?.load(as: MIDINoteMessage.self) {
                    if convertedData.note == MIDIByte(note) {
                        MusicEventIteratorDeleteEvent(iterator)
                        isReadyForNextEvent = false
                    }
                }
            }

            if isReadyForNextEvent { MusicEventIteratorNextEvent(iterator) }
            MusicEventIteratorHasCurrentEvent(iterator, &hasNextEvent)
        }
        DisposeMusicEventIterator(iterator)
    }

    /// Clear a specific meta event
    public func clearMetaEvent(_ metaEventType: MIDIByte) {
        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return
        }
        var tempIterator: MusicEventIterator?
        NewMusicEventIterator(track, &tempIterator)
        guard let iterator = tempIterator else {
            //Log("Unable to create iterator in clearNote")
            return
        }
        var eventTime = MusicTimeStamp(0)
        var eventType = MusicEventType()
        var eventData: UnsafeRawPointer?
        var eventDataSize: UInt32 = 0
        var hasNextEvent: DarwinBoolean = false
        var isReadyForNextEvent: Bool

        MusicEventIteratorHasCurrentEvent(iterator, &hasNextEvent)
        while hasNextEvent.boolValue {
            isReadyForNextEvent = true
            MusicEventIteratorGetEventInfo(iterator,
                                           &eventTime,
                                           &eventType,
                                           &eventData,
                                           &eventDataSize)
            if eventType == kMusicEventType_Meta {
                if let convertedData = eventData?.load(as: MIDIMetaEvent.self) {
                    if convertedData.metaEventType == metaEventType {
                        MusicEventIteratorDeleteEvent(iterator)
                        isReadyForNextEvent = false
                    }
                }
            }

            if isReadyForNextEvent { MusicEventIteratorNextEvent(iterator) }
            MusicEventIteratorHasCurrentEvent(iterator, &hasNextEvent)
        }
        DisposeMusicEventIterator(iterator)
    }

    /// Determine if the sequence is empty
    open var isEmpty: Bool {
        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return true
        }
        var tempIterator: MusicEventIterator?
        NewMusicEventIterator(track, &tempIterator)
        guard let iterator = tempIterator else {
            //Log("Unable to create iterator in isEmpty")
            return true
        }
        var outBool = true
        var eventTime = MusicTimeStamp(0)
        var eventType = MusicEventType()
        var eventData: UnsafeRawPointer?
        var eventDataSize: UInt32 = 0
        var hasNextEvent: DarwinBoolean = false
        MusicEventIteratorHasCurrentEvent(iterator, &hasNextEvent)
        while hasNextEvent.boolValue {
            MusicEventIteratorGetEventInfo(iterator,
                                           &eventTime,
                                           &eventType,
                                           &eventData,
                                           &eventDataSize)

            outBool = false
            MusicEventIteratorNextEvent(iterator)
            MusicEventIteratorHasCurrentEvent(iterator, &hasNextEvent)
        }
        DisposeMusicEventIterator(iterator)
        return outBool
    }

    /// Clear all events from this track within the specified range
    ///
    /// - Parameters:
    ///   - start: Start of the range to clear, in beats (inclusive)
    ///   - duration: Length of time after the start position to clear, in beats (exclusive)
    ///
    public func clearRange(start: Duration, duration: Duration) {
        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return
        }

        if isNotEmpty {
            MusicTrackClear(track, start.beats, start.beats + duration.beats)
        }
    }

    // MARK: Add Events

    /// Add Note to sequence
    ///
    /// - Parameters:
    ///   - noteNumber: The MIDI note number to insert
    ///   - velocity: The velocity to insert note at
    ///   - position: Where in the sequence to start the note (expressed in beats)
    ///   - duration: How long to hold the note (would be better if they let us just use noteOffs...oh well)
    ///   - channel: MIDI channel for this note
    ///
    public func add(noteNumber: MIDINoteNumber,
                    velocity: MIDIVelocity,
                    position: Duration,
                    duration: Duration,
                    channel: MIDIChannel = 0)
    {
        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return
        }

        var noteMessage = MIDINoteMessage(channel: channel,
                                          note: noteNumber,
                                          velocity: velocity,
                                          releaseVelocity: 0,
                                          duration: Float32(duration.beats))

        MusicTrackNewMIDINoteEvent(track, position.musicTimeStamp, &noteMessage)
    }

    /// Add Note to sequence with MIDINoteData
    ///
    /// - parameter midiNoteData: MIDINoteData containing relevant note details
    ///
    public func add(midiNoteData: MIDINoteData) {
        add(noteNumber: midiNoteData.noteNumber,
            velocity: midiNoteData.velocity,
            position: midiNoteData.position,
            duration: midiNoteData.duration,
            channel: midiNoteData.channel)
    }

    /// Erases current note events and recreates track from note data in MIDINoteData array
    /// Order of structs in array is irrelevant
    ///
    /// - parameter midiNoteData: MIDINoteData array containing relevant note details
    ///
    public func replaceMIDINoteData(with trackMIDINoteData: [MIDINoteData]) {
        clearRange(start: Duration(beats: 0), duration: Duration(beats: length))
        for data in trackMIDINoteData { add(midiNoteData: data) }
    }

    /// Add Controller change to sequence
    ///
    /// - Parameters:
    ///   - controller: The MIDI controller to insert
    ///   - value: The velocity to insert note at
    ///   - position: Where in the sequence to start the note (expressed in beats)
    ///   - channel: MIDI channel for this note
    ///
    public func addController(_ controller: MIDIByte,
                              value: MIDIByte,
                              position: Duration,
                              channel: MIDIChannel = 0)
    {
        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return
        }
        var controlMessage = MIDIChannelMessage(status: MIDIByte(11 << 4) | MIDIByte(channel & 0xF),
                                                data1: controller,
                                                data2: value,
                                                reserved: 0)
        MusicTrackNewMIDIChannelEvent(track, position.musicTimeStamp, &controlMessage)
    }

    /// Add polyphonic key pressure (a.k.a aftertouch)
    ///
    /// - Parameters:
    ///   - noteNumber: Note to apply the pressure to
    ///   - pressure: Amount of pressure
    ///   - position: Where in the sequence to start the note (expressed in beats)
    ///   - channel: MIDI channel for this event
    public func addAftertouch(_ noteNumber: MIDINoteNumber,
                              pressure: MIDIByte,
                              position: Duration, channel: MIDIChannel = 0)
    {
        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return
        }

        var message = MIDIChannelMessage(status: MIDIByte(10 << 4) | MIDIByte(channel & 0xF),
                                         data1: noteNumber,
                                         data2: pressure,
                                         reserved: 0)
        MusicTrackNewMIDIChannelEvent(track, position.musicTimeStamp, &message)
    }

    /// Add channel pressure (a.k.a. global aftertouch)
    ///
    /// - Parameters:
    ///   - pressure: Amount of pressure
    ///   - position: Where in the sequence to start the note (expressed in beats)
    ///   - channel: MIDI channel for this event
    public func addChannelAftertouch(pressure: MIDIByte,
                                     position: Duration,
                                     channel: MIDIChannel = 0)
    {
        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return
        }

        var message = MIDIChannelMessage(status: MIDIByte(13 << 4) | MIDIByte(channel & 0xF),
                                         data1: pressure,
                                         data2: 0,
                                         reserved: 0)
        MusicTrackNewMIDIChannelEvent(track, position.musicTimeStamp, &message)
    }

    /// Add SysEx message to sequence
    ///
    /// - Parameters:
    ///   - data: The MIDI data byte array - standard SysEx start and end messages are added automatically
    ///   - position: Where in the sequence to start the note (expressed in beats)
    ///
    public func addSysEx(_ data: [MIDIByte], position: Duration) {
        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return
        }
        var midiData = MIDIRawData()
        midiData.length = UInt32(data.count)

        withUnsafeMutablePointer(to: &midiData.data) { pointer in
            for i in 0 ..< data.count {
                pointer[i] = data[i]
            }
        }

        let result = MusicTrackNewMIDIRawDataEvent(track, position.musicTimeStamp, &midiData)
        if result != 0 {
            //Log("Unable to insert raw midi data")
        }
    }

    /// Add MetaEvent to sequence
    ///
    /// - Parameters:
    ///   - data: The MIDI data byte array - standard bytes containing the length of the data are added automatically
    ///   - position: Where in the sequence to start the note (expressed in beats)
    ///
    public func addMetaEvent(metaEventType: MIDIByte,
                             data: [MIDIByte],
                             position: Duration = Duration(beats: 0)) {
        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return
        }
        let metaEventPtr = MIDIMetaEvent.allocate(metaEventType: metaEventType, data: data)
        defer { metaEventPtr.deallocate() }

        let result = MusicTrackNewMetaEvent(track, position.musicTimeStamp, metaEventPtr)
        if result != 0 {
            //Log("Unable to write meta event")
        }
    }

    /// Add Pitch Bend change to sequence
    ///
    /// - Parameters:
    ///   - value: The value of pitchbend. The valid range of values is 0 to 16383 (128 ^ 2 values).
    ///   - 8192 is no pitch bend.
    ///   - position: Where in the sequence to insert pitchbend info (expressed in beats)
    ///   - channel: MIDI channel to insert pitch bend on
    ///
    public func addPitchBend(_ value: Int = 8192,
                             position: Duration,
                             channel: MIDIChannel = 0)
    {
        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return
        }
        // Find least and most significant bytes, remembering they are 7 bit numbers.
        let lsb = value & 0x7F
        let msb = (value >> 7) & 0x7F
        var pitchBendMessage = MIDIChannelMessage(status: MIDIByte(14 << 4) | MIDIByte(channel & 0xF),
                                                  data1: MIDIByte(lsb),
                                                  data2: MIDIByte(msb),
                                                  reserved: 0)
        MusicTrackNewMIDIChannelEvent(track, position.musicTimeStamp, &pitchBendMessage)
    }

    /// Add Pitch Bend reset to sequence
    ///
    /// - Parameters:
    ///   - position: Where in the sequence to insert pitchbend info (expressed in beats)
    ///   - channel: MIDI channel to insert pitch bend reset on
    ///
    public func resetPitchBend(position: Duration, channel: MIDIChannel = 0) {
        addPitchBend(8192, position: position, channel: channel)
    }

    // MARK: Getting data from MusicTrack

    /// Get an array of all the MIDI Note data in the internalMusicTrack
    /// Modifying this array alone will not change the internalMusicTrack
    ///
    /// NB: The data is generated sequentially, but maintaining the order in not important
    ///
    public func getMIDINoteData() -> [MIDINoteData] {
        var noteData = [MIDINoteData]()

        guard let track = internalMusicTrack else {
            //Log("internalMusicTrack does not exist")
            return []
        }

        MusicTrackManager.iterateMusicTrack(track) { _, eventTime, eventType, eventData, _, _ in
            guard eventType == kMusicEventType_MIDINoteMessage else { return }
            let data = eventData?.bindMemory(to: MIDINoteMessage.self, capacity: 1)

            guard let channel = data?.pointee.channel,
                  let note = data?.pointee.note,
                  let velocity = data?.pointee.velocity,
                  let dur = data?.pointee.duration
            else {
                //Log("Problem with raw midi note message")
                return
            }
            let noteDetails = MIDINoteData(noteNumber: note,
                                           velocity: velocity,
                                           channel: channel,
                                           duration: Duration(beats: Double(dur)),
                                           position: Duration(beats: eventTime))

            noteData.append(noteDetails)
        }

        return noteData
    }

    /// Copy this track to another track
    ///
    /// - parameter musicTrack: Destination track to copy this track to
    ///
    public func copyAndMergeTo(musicTrack: MusicTrackManager) {
        guard let track = internalMusicTrack,
              let mergedToTrack = musicTrack.internalMusicTrack
        else {
            //Log("internalMusicTrack does not exist")
            return
        }
        MusicTrackMerge(track, 0.0, length, mergedToTrack, 0.0)
    }

    /// Copy this track to another track
    ///
    /// - returns a copy of this track that can be edited independently
    ///
    public func copyOf() -> MusicTrackManager? {
        let copiedTrack = MusicTrackManager()

        guard let internalMusicTrack = internalMusicTrack,
              let copiedInternalTrack = copiedTrack.internalMusicTrack
        else {
            return nil
        }
        MusicTrackMerge(internalMusicTrack, 0.0, length, copiedInternalTrack, 0.0)
        return copiedTrack
    }

    /// Reset to initial values
    public func resetToInit() {
        var initLengthCopy: Double = initLength
        clear()
        if let internalMusicTrack = internalMusicTrack, let existingInittrack = initMusicTrack {
            setLength(Duration(beats: initLength))
            _ = MusicTrackSetProperty(existingInittrack,
                                      kSequenceTrackProperty_TrackLength,
                                      &initLengthCopy,
                                      0)
            MusicTrackMerge(existingInittrack, 0.0, length, internalMusicTrack, 0.0)
        }
    }

    /// Generalized method for iterating thru a CoreMIDI MusicTrack with a closure to handle events
    ///
    /// - Parameters:
    ///   - track: a MusicTrack (either internalTrack or AppleSequencer tempo track) to iterate thru
    ///   - midiEventHandler: a closure taking MusicEventIterator, MusicTimeStamp, MusicEventType,
    ///     UnsafeRawPointer? (eventData), UInt32 (eventDataSize) as input and handles the events
    ///
    class func iterateMusicTrack(_ track: MusicTrack,
                                 midiEventHandler: (MusicEventIterator,
                                                    MusicTimeStamp,
                                                    MusicEventType,
                                                    UnsafeRawPointer?,
                                                    UInt32,
                                                    inout Bool) -> Void)
    {
        var tempIterator: MusicEventIterator?
        NewMusicEventIterator(track, &tempIterator)
        guard let iterator = tempIterator else {
            //Log("Unable to create iterator")
            return
        }
        var eventTime = MusicTimeStamp(0)
        var eventType = MusicEventType()
        var eventData: UnsafeRawPointer?
        var eventDataSize: UInt32 = 0
        var hasNextEvent: DarwinBoolean = false
        var isReadyForNextEvent = true

        MusicEventIteratorHasCurrentEvent(iterator, &hasNextEvent)
        while hasNextEvent.boolValue {
            MusicEventIteratorGetEventInfo(iterator,
                                           &eventTime,
                                           &eventType,
                                           &eventData,
                                           &eventDataSize)

            midiEventHandler(iterator,
                             eventTime,
                             eventType,
                             eventData,
                             eventDataSize,
                             &isReadyForNextEvent)

            if isReadyForNextEvent { MusicEventIteratorNextEvent(iterator) }
            MusicEventIteratorHasCurrentEvent(iterator, &hasNextEvent)
        }
        DisposeMusicEventIterator(iterator)
    }

    /// Set the MIDI Output
    ///
    /// - parameter endpoint: MIDI Endpoint Port
    ///
    @available(tvOS 12.0, *)
    public func setMIDIOutput(_ endpoint: MIDIEndpointRef) {
        if let track = internalMusicTrack {
            if MusicTrackSetDestMIDIEndpoint(track, endpoint) == kAudioToolboxErr_InvalidPlayerState {
               // //Log("🛑 Error: InvalidPlayerState. Please stop any sequencer playback before performing this operation.")
            }
        }
    }
}

// MARK: -

public struct MIDINoteData: CustomStringConvertible, Equatable {
    /// MIDI Note Number
    public var noteNumber: MIDINoteNumber

    /// MIDI Velocity
    public var velocity: MIDIVelocity

    /// MIDI Channel
    public var channel: MIDIChannel

    /// Note duration
    public var duration: Duration

    /// Note position as a duration from the start
    public var position: Duration

    /// Initialize the MIDI Note Data
    /// - Parameters:
    ///   - noteNumber: MID Note Number
    ///   - velocity: MIDI Velocity
    ///   - channel: MIDI Channel
    ///   - duration: Note duration
    ///   - position: Note position as a duration from the start
    public init(noteNumber: MIDINoteNumber,
                velocity: MIDIVelocity,
                channel: MIDIChannel,
                duration: Duration,
                position: Duration) {
        self.noteNumber = noteNumber
        self.velocity = velocity
        self.channel = channel
        self.duration = duration
        self.position = position
    }

    /// Pretty printout
    public var description: String {
        return """
        note: \(noteNumber)
        velocity: \(velocity)
        channel: \(channel)
        duration: \(duration.beats)
        position: \(position.beats)
        """
    }
}

extension MIDIMetaEvent {
    /// `MIDIMetaEvent` is a variable length C structure. YOU MUST create one using this function
    ///  if the data is of length > 0.
    /// - Parameters:
    ///   - metaEventType: type of event
    ///   - data: event data
    /// - Returns: pointer to allocated event.
    static func allocate(metaEventType: MIDIByte, data: [MIDIByte]) -> UnsafeMutablePointer<MIDIMetaEvent> {
        let size = MemoryLayout<MIDIMetaEvent>.size + data.count
        let mem = UnsafeMutableRawPointer.allocate(byteCount: size,
                                                   alignment: MemoryLayout<Int8>.alignment)
        let ptr = mem.bindMemory(to: MIDIMetaEvent.self, capacity: 1)

        ptr.pointee.metaEventType = metaEventType
        ptr.pointee.dataLength = UInt32(data.count)

        withUnsafeMutablePointer(to: &ptr.pointee.data) { pointer in
            for i in 0 ..< data.count {
                pointer[i] = data[i]
            }
        }

        return ptr
    }
}

// MARK: -

extension MIDIPacketList: Sequence {
    /// The element is a packet list sequence is a MIDI Packet
    public typealias Element = MIDIPacket

    /// Number of packets
    public var count: UInt32 {
        return self.numPackets
    }

    /// Create the sequence
    /// - Returns: Iterator of elements
    public func makeIterator() -> AnyIterator<Element> {
        // Copy packets to prevent AddressSanitizer: stack-use-after-return on address
        let packets = withUnsafePointer(to: packet) { ptr in
            var packets = [MIDIPacket]()
            var p = ptr

            for _ in 0..<numPackets {
                if let packet = extractPacket(p) {
                    packets.append(packet)
                } else {
                    // If a packet cannot be extracted, return already extracted and ignore all
                    // subsequent packets.
                    return packets
                }

                p = UnsafePointer(MIDIPacketNext(p))
            }

            return packets
        }

        return AnyIterator(packets.makeIterator())
    }
}


/// We can't call pointee on a packet pointer without potentially reading off the end and
/// triggering ASAN. Instead extract the data.
public func extractPacketData(_ ptr: UnsafePointer<MIDIPacket>) -> [UInt8] {

    let raw = UnsafeRawPointer(ptr)
    let dataPtr = raw.advanced(by: MemoryLayout.offset(of: \MIDIPacket.data)!)

    let length = Int(raw.loadUnaligned(fromByteOffset: MemoryLayout.offset(of: \MIDIPacket.length)!,
                                       as: UInt16.self))

    var array = [UInt8](repeating: 0, count: length)
    memcpy(&array, dataPtr, length)

    return array
}

public func extractPacket(_ ptr: UnsafePointer<MIDIPacket>) -> MIDIPacket? {

    var packet = MIDIPacket()
    let raw = UnsafeRawPointer(ptr)

    let length = raw.loadUnaligned(fromByteOffset: MemoryLayout.offset(of: \MIDIPacket.length)!,
                                   as: UInt16.self)

    // We can't represent a longer packet as a MIDIPacket value.
    if length > 256 {
        return nil
    }

    packet.length = length
    packet.timeStamp = raw.loadUnaligned(fromByteOffset: MemoryLayout.offset(of: \MIDIPacket.timeStamp)!,
                                         as: MIDITimeStamp.self)

    let dataPtr = raw.advanced(by: MemoryLayout.offset(of: \MIDIPacket.data)!)
    _ = withUnsafeMutableBytes(of: &packet.data) { ptr in
        memcpy(ptr.baseAddress!, dataPtr, Int(length))
    }

    return packet
}

extension Array {
  init?<Subject>(mirrorChildValuesOf subject: Subject) {
    guard let array = Mirror(reflecting: subject).children.map(\.value) as? Self
    else { return nil }

    self = array
  }
}

