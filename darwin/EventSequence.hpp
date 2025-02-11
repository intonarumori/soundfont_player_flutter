
#pragma once

#ifdef __cplusplus

#define MAX_EVENT_COUNT 128


typedef struct TrackEvent {
    double timestamp;
    uint8_t status;
    uint8_t data1;
    uint8_t data2;
    uint32_t userData;
} TrackEvent;

class Track {
public:
    Track() {
        eventCount = 0;
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
        for (int j = index; j < eventCount; j++) {
            events[j] = events[j + 1];
        }
        eventCount--;
    }
    
    int eventCount;
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

#endif
