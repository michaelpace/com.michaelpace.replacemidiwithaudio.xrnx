renoise.tool():add_menu_entry {
	name = "Main Menu:Tools:Replace midi with audio",
	invoke = function() replaceMidiWithAudio() end
}

renoise.tool():add_keybinding {
	name = "Pattern Editor:Track Control:Replace midi with audio",
	invoke = function(repeated)
		if (not repeated)
		then
			replaceMidiWithAudio()
		end
	end
}

function replaceMidiWithAudio()
    local song = renoise.song()

    local midiTrackIndex = -1
    local audioTrackIndex = -1

    if selectedTrackIsInAGroup() then

        midiTrackIndex = song.selected_track_index
        audioTrackIndex = midiTrackIndex + 1

    else

        local originalTrackName = song.tracks[song.selected_track_index].name

        -- create group track
        local groupTrackIndex = song.selected_track_index
        song:insert_group_at(groupTrackIndex)
        song.tracks[groupTrackIndex].name = "GROUP: " .. originalTrackName

        -- add midi track to group
        midiTrackIndex = groupTrackIndex + 1
        song:add_track_to_group(midiTrackIndex, groupTrackIndex)
        groupTrackIndex = midiTrackIndex
        midiTrackIndex = groupTrackIndex - 1
        song.tracks[midiTrackIndex].name = "MIDI: " .. originalTrackName

        -- add audio track to group
        audioTrackIndex = groupTrackIndex + 1
        song:insert_track_at(audioTrackIndex)
        song:add_track_to_group(audioTrackIndex, groupTrackIndex)
        groupTrackIndex = audioTrackIndex
        audioTrackIndex = groupTrackIndex - 1
        song.tracks[audioTrackIndex].name = "AUDIO: " .. originalTrackName

        -- copy track devices from midi track to group track
        local midiTrackDevices = song.tracks[midiTrackIndex].devices
        local targetDeviceIndex = 2
        for i=2, #midiTrackDevices, 1 do  -- start at 2, since index 1 is always the volume / pan device
            local midiTrackDevice = midiTrackDevices[i]
            local path = midiTrackDevice.device_path

            if not path:find("*Signal Follower") then
                local groupTrackDevice = song.tracks[groupTrackIndex]:insert_device_at(path, targetDeviceIndex)

                local deviceParameters = midiTrackDevice.parameters
                for j=1, #deviceParameters, 1 do
                    groupTrackDevice.parameters[j].value = midiTrackDevice.parameters[j].value
                end

                targetDeviceIndex = targetDeviceIndex + 1
            end
        end

        -- delete track devices from midi track
        local midiTrackDevices = song.tracks[midiTrackIndex].devices
        for i=#midiTrackDevices, 2, -1 do  -- stop at 2, since index 1 is always the volume / pan device
            local midiTrackDevice = midiTrackDevices[i]
            local path = midiTrackDevice.device_path

            if not path:find("*Signal Follower") then
                song.tracks[midiTrackIndex]:delete_device_at(i)
            end
        end
    end

    -- mute midi track
    song.tracks[midiTrackIndex]:mute()

    -- collapse midi track
    song.tracks[midiTrackIndex].collapsed = true

    -- paste sample into audio track
    song.patterns[song.selected_pattern_index].tracks[audioTrackIndex].lines[1].note_columns[1].note_string = "C-4"
    song.patterns[song.selected_pattern_index].tracks[audioTrackIndex].lines[1].note_columns[1].instrument_value = song.selected_instrument_index - 1
end

function selectedTrackIsInAGroup()
    local song = renoise.song()

    local selectedTrack = song.selected_track

    local tracks = song.tracks

    for i=1, #tracks, 1 do
        if tracks[i].type == renoise.Track.TRACK_TYPE_GROUP then
            local members = tracks[i].members
            for j=1, #members, 1 do
                if members[j].name == selectedTrack.name and members[j].color_blend == selectedTrack.color_blend then
                    return true
                end
            end
        end
    end

    return false
end
