on run argv
    set separatorCharacter to character id 30
    set artworkOutputPath to item 1 of argv

tell application "Music"
    set stateText to player state as text
    if stateText is "stopped" then return ""

    set mediaTrack to current track
    set trackIdentifier to ""
    try
        set trackIdentifier to persistent ID of mediaTrack as text
    end try

    set trackTitle to name of mediaTrack as text
    set trackArtist to ""
    set trackAlbum to ""
    try
        set trackArtist to artist of mediaTrack as text
    end try
    try
        set trackAlbum to album of mediaTrack as text
    end try

    try
        set artworkData to raw data of artwork 1 of mediaTrack
    on error
        set artworkData to missing value
    end try
end tell

    set artworkPathText to ""
    if artworkData is not missing value then
        try
            set artworkFile to POSIX file artworkOutputPath
            set fileReference to open for access artworkFile with write permission
            set eof of fileReference to 0
            write artworkData to fileReference
            close access fileReference
            set artworkPathText to artworkOutputPath
        on error
            try
                close access fileReference
            end try
        end try
    end if

    return "appleMusic" & separatorCharacter & stateText & separatorCharacter & trackIdentifier & separatorCharacter & trackTitle & separatorCharacter & trackArtist & separatorCharacter & trackAlbum & separatorCharacter & artworkPathText
end run
