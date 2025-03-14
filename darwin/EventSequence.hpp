
#pragma once

#ifdef __cplusplus

#define MAX_EVENT_COUNT 128


enum class TrackEventType {
    noteOn,
    noteOff
};

struct TrackEvent {
    double timestamp;
    TrackEventType type;
    uint8_t data1;
    uint8_t data2;
    uint32_t userData;
};

class Track {
public:
    Track() {
        eventCount = 0;
        length = 4;
    }
    ~Track() {}

    Track& operator=(const Track& other) {
        if (this == &other)  // Self-assignment check
            return *this;
        eventCount = other.eventCount;
        for (int i = 0; i < eventCount; i++) {
            events[i] = other.events[i];
        }
        return *this;
    }
    
    void addEvent(TrackEvent event) {
        events[eventCount] = event;
        eventCount++;
    }
    
    int eventIndexWithTimestamp(double timestamp) {
        for (int i = 0; i < eventCount; i++) {
            if (events[i].timestamp == timestamp) {
                return i;
            }
        }
        return -1;
    }

    void removeEventAtIndex(int index) {
        if (eventCount == 0) return;
        for (int j = index; j < eventCount; j++) {
            events[j] = events[j + 1];
        }
        eventCount--;
    }

    int eventCount;
    double length;
    TrackEvent events[MAX_EVENT_COUNT];
};

class Sequence {
public:
    
    void setTrack(int index, Track & track) {
        tracks[index] = track;
    }
    
    static const int numberOfTracks = 8;
    Track tracks[numberOfTracks];
    double length;
};


// MARK: -

struct PlayingNote {
    int16_t shiftedNote;
    int16_t eventNote;
    bool active;
};

struct PlayingNotes {
    
    PlayingNotes() {
        for (int i = 0; i < 16; i++) {
            mPlayingNotes[i].active = false;
        }
    }
    
    bool isPlayingNote(int note) {
        for (int i = 0; i < 16; i++) {
            if (mPlayingNotes[i].active && mPlayingNotes[i].eventNote == note) return true;
        }
        return false;
    }
    
    bool isActiveNote(int index, int * note) {
        if (mPlayingNotes[index].active) {
            *note = mPlayingNotes[index].eventNote;
            return true;
        }
        return false;
    }
    
    void deactiveNote(int index) {
        mPlayingNotes[index].active = false;
    }
    
    void activateNote(int index, int note, int shiftedNote) {
        mPlayingNotes[index].active = true;
        mPlayingNotes[index].eventNote = note;
        mPlayingNotes[index].shiftedNote = shiftedNote;
    }
    
    int getShiftedNote(int index) {
        return mPlayingNotes[index].shiftedNote;
    }
    
    PlayingNote mPlayingNotes[16];
};

#endif
