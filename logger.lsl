/*
Trip logging script for Second Life
Copyright 2024, NovaSquirrel

Copying and distribution of this file, with or without modification, are permitted in any medium without royalty, provided the copyright notice and this notice are preserved. This file is offered as-is, without any warranty.
*/
#define MINIMUM_DISTANCE_REQUIRED 2.5
#define TIMER_FREQUENCY 2
#define MAX_RECORD_LENGTH 5000

string region_name;       // used to detect when crossing into a new region
vector last_position;     // most recent recorded point's position
string current_record;    // region x, region y, sequence of XXYY pairs
integer record_count = 0; // how many records are in the linkset data
integer active = 0;       // actively recording
integer paused = 0;       // paused recording
integer total_points = 0; // amount of points that have been recorded

integer dialog_channel;
integer marker_channel;
integer listener;
integer configure_mode; // The marker input is actually for configuration

// Configuration
integer timer_frequency = TIMER_FREQUENCY;
float minimum_distance_required = MINIMUM_DISTANCE_REQUIRED;

string encode_byte(integer n) {
    if(n < 0)
        n = 0;
    if(n > 255)
        n = 255;
    integer i;
    return llChar(n+32);
}

write_current_record() {
    if(current_record == "")
        return;
    if(llLinksetDataWrite((string)record_count, current_record) == LINKSETDATA_EMEMORY) {
        llOwnerSay("Ending this trip due to a lack of memory");
        active = 0;
    }
    record_count += 1;
    region_name = ""; // Make the next point fetch the region again
    current_record = "";
}

init_record(string prefix) {
    write_current_record();
    region_name = llGetRegionName();
    vector corner = llGetRegionCorner();
    integer region_x = (integer)(corner.x / 256);
    integer region_y = (integer)(corner.y / 256);
    current_record = prefix+encode_byte(region_x&255) + encode_byte(region_x>>8) + encode_byte(region_y&255) + encode_byte(region_y>>8);
}

add_coordinate_to_record(vector coordinate) {
    current_record += encode_byte((integer)llFloor(coordinate.x)) + encode_byte((integer)(llFloor(coordinate.y)));
    total_points += 1;
}

default {    
    timer() {
        if(active == 0 || paused == 1)
            return;
        // Start a new record if the user is in a new region
        if(llGetRegionName() != region_name || llStringLength(current_record) > MAX_RECORD_LENGTH) {
            init_record("+");
            add_coordinate_to_record(llGetRootPosition());
            return;
        }
        vector current_position = llGetRootPosition();
        if(llSqrt(llPow(current_position.x-last_position.x, 2)+llPow(current_position.y-last_position.y, 2)) > minimum_distance_required) {
            add_coordinate_to_record(current_position);
            last_position = current_position;
        }
    }
    
    state_entry() {
        dialog_channel = (integer)(llFrand(-1000000000.0) - 1000000000.0);
        marker_channel = dialog_channel + 1;
        llSetTimerEvent(TIMER_FREQUENCY);
    }
    
    touch_start(integer total_number) {
        llListenRemove(listener);
        listener = llListen(dialog_channel, "", llDetectedKey(0), "");
        string message = "Not currently recording";
        if(active) {
            message = "Points recorded: " + (string)total_points+" points";
            if(paused) {
                message += "\n(Paused)";
            }
        }
        message += "\n\nConfiguration: Record every " + (string)timer_frequency + " seconds, if you've moved " + (string)minimum_distance_required + " meters";
     
        llDialog(llDetectedKey(0), message, [
        llList2String(["Start!", "Finish"], active), 
        llList2String(["Pause", "Resume"], paused),
        "Cancel", "Get data", "Add marker", "Configure"
        ], dialog_channel);
    }
    
    listen(integer channel, string name, key id, string option) {
        llListenRemove(listener);
        if(channel == dialog_channel) {
            if(option == "Start!") {
                llLinksetDataReset();
                region_name = "";
                current_record = "";
                total_points = 0;
                record_count = 0;
                active = 1;
                paused = 0;
                llOwnerSay("Started recording!");
            } else if(option == "Finish") {
                write_current_record();
                active = 0;
                llOwnerSay("Stopped recording at "+(string)total_points+" points!");
            } else if(option == "Pause") {
                paused = 1;
                llOwnerSay("Pausing");
            } else if(option == "Resume") {
                paused = 0;
                llOwnerSay("Unpausing");
            } else if(option == "Get data") {
                write_current_record();
                llMessageLinked(LINK_THIS, record_count, "show_url", "");
            } else if(option == "Add marker") {
                llTextBox(id, "Add a marker with this text:", marker_channel);
                listener = llListen(marker_channel, "", id, "");
                configure_mode = 0;
            } else if(option == "Configure") {
                llTextBox(id, "How frequently (in seconds) should points be recorded? Default is 2", marker_channel);
                listener = llListen(marker_channel, "", id, "");
                configure_mode = 1;
            }
        } else if(channel == marker_channel) {
            if(configure_mode == 0) {
                init_record("!");
                add_coordinate_to_record(llGetRootPosition());
                current_record += option;
                write_current_record();
            } else if(configure_mode == 1) {
                timer_frequency = (integer)option;
                llSetTimerEvent(timer_frequency);
                llTextBox(id, "How far in meters should you have to move before another point is recorded? Default is 2.5", marker_channel);
                listener = llListen(marker_channel, "", id, "");
                configure_mode = 2;
            } else if(configure_mode == 2) {
                minimum_distance_required = (float)option;
                configure_mode = 0;
            }
        }
    }
}
