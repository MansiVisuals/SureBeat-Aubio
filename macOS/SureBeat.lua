-- SureBeat by Mansi Visuals (macOS Version:

-- Define paths to Aubio and FFmpeg binaries
local aubioonset_path = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/SureBeat/Aubio/bin/aubioonset"
local aubiotempo_path = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/SureBeat/Aubio/bin/aubiotempo"
local aubio_lib_path = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/SureBeat/Aubio/lib"
local ffmpeg_path = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/SureBeat/FFmpeg/bin/ffmpeg"

-- Variables to store transient and tempo information
local transients = {}
local tempo_bpm = 0

-- Function to convert any audio file to .wav using FFmpeg
function convert_to_wav(input_path)
    local output_path = os.tmpname() .. ".wav"  -- Temporary .wav file
    local command = string.format('"%s" -i "%s" -acodec pcm_s16le -ar 44100 "%s"', ffmpeg_path, input_path, output_path)
    print("Running conversion command:", command)
    os.execute(command)
    print("Conversion completed:", output_path)
    return output_path
end

-- Function to detect transients using aubioonset
function detect_transients_with_aubioonset(audio_path)
    print("Starting transient detection using aubioonset with HFC method for percussive sounds")
    local onset_command = string.format('DYLD_LIBRARY_PATH="%s" "%s" -O hfc -t 0.3 -s -40 "%s"', aubio_lib_path, aubioonset_path, audio_path)
    local onset_handle = io.popen(onset_command)
    local onset_output = onset_handle:read("*a")
    onset_handle:close()

    transients = {}
    for line in onset_output:gmatch("[^\r\n]+") do
        local onset_time = tonumber(line:match("([%d%.]+)"))
        if onset_time then
            local marker_time, peak_amplitude = analyze_peak(audio_path, onset_time, 0.02)  -- 20 ms segment
            table.insert(transients, { onset = marker_time, peak = peak_amplitude })
            print(string.format("Transient detected at %.3f seconds with peak amplitude %.3f", marker_time, peak_amplitude))
        end
    end
    print("Transient detection completed. Total transients detected:", #transients)
    return #transients > 0
end

-- Function to analyze peak amplitude and set marker time directly at the peak for each onset segment
function analyze_peak(audio_file, onset_time, segment_duration)
    local segment_file = os.tmpname() .. ".wav"
    local extract_command = string.format('"%s" -i "%s" -ss %f -t %f -acodec pcm_s16le "%s"', ffmpeg_path, audio_file, onset_time, segment_duration, segment_file)
    os.execute(extract_command)

    local peak_amplitude = 0
    local peak_time_relative = 0
    local analyze_command = string.format('"%s" -i "%s" -af "astats=metadata=1:reset=1" -f null - 2>&1', ffmpeg_path, segment_file)
    local handle = io.popen(analyze_command)
    local time_position = 0  -- Track time in the segment
    for line in handle:lines() do
        local amp = tonumber(line:match("Max level:%s*(-?%d+%.?%d*)"))
        if amp and amp > peak_amplitude then
            peak_amplitude = amp
            peak_time_relative = time_position
        end
        time_position = time_position + 0.001  -- Increment by 1 ms for granularity
    end
    handle:close()
    os.remove(segment_file)

    print("Peak analysis completed for segment. Peak amplitude:", peak_amplitude)
    return onset_time + peak_time_relative, peak_amplitude
end

-- Function to analyze and calculate the BPM (tempo) of the audio using aubiotempo
function analyze_tempo(audio_path)
    print("Calculating tempo using aubiotempo")
    local tempo_command = string.format('DYLD_LIBRARY_PATH="%s" "%s" "%s"', aubio_lib_path, aubiotempo_path, audio_path)
    local handle = io.popen(tempo_command)
    local bpm_output = handle:read("*a")
    handle:close()

    tempo_bpm = tonumber(bpm_output:match("([%d%.]+)"))
    print(string.format("Tempo analysis complete. Detected tempo: %.2f BPM", tempo_bpm))
    return tempo_bpm
end

-- Function to add markers based on detected transients and/or tempo
function add_markers(win, audio_file_name, add_transients, add_tempo)
    local resolve = Resolve()
    local projectManager = resolve:GetProjectManager()
    local project = projectManager:GetCurrentProject()
    local timeline = project:GetCurrentTimeline()
    if not timeline then
        print("No active timeline found.")
        return false
    end

    local frame_rate = tonumber(timeline:GetSetting("timelineFrameRate"))
    local track_count = timeline:GetTrackCount("audio")
    local target_clip, clip_start_frame, clip_end_frame = nil, 0, 0

    for track = 1, track_count do
        for _, clip in ipairs(timeline:GetItemsInTrack("audio", track)) do
            if clip:GetName():find(audio_file_name, 1, true) then
                target_clip = clip
                clip_start_frame = math.floor(clip:GetStart() * frame_rate)
                clip_end_frame = math.floor(clip:GetEnd() * frame_rate)
                break
            end
        end
        if target_clip then break end
    end

    if not target_clip then
        print("Failed to create markers. Could not find matching audio clip on the timeline.")
        win:GetItems().InfoDisplay:SetText("Failed to create markers. Could not find matching audio clip on the timeline.")
        return false
    end

    if add_transients then
        print("Adding transient markers to timeline...")
        for _, transient in ipairs(transients) do
            local relative_frame = math.floor(transient.onset * frame_rate)
            if clip_start_frame + relative_frame <= clip_end_frame then
                print(string.format("Adding red transient marker at frame %d (%.3f seconds)", relative_frame, transient.onset))
                target_clip:AddMarker(relative_frame, "Red", "Transient", string.format("Peak: %.3f", transient.peak), 1)
            end
        end
    end

    if add_tempo and tempo_bpm > 0 then
        print("Adding tempo markers to timeline...")
        local interval_seconds = 60 / tempo_bpm
        local current_time = 0
        while current_time * frame_rate + clip_start_frame <= clip_end_frame do
            local marker_frame = math.floor(current_time * frame_rate)
            print(string.format("Adding cream tempo marker at frame %d (%.3f seconds)", marker_frame, current_time))
            target_clip:AddMarker(marker_frame, "Cream", "Tempo", string.format("Tempo: %.2f BPM", tempo_bpm), 1)
            current_time = current_time + interval_seconds
        end
    end
    print("Marker addition completed successfully.")
    return true
end

-- Main function with UI for detecting transients and creating markers
function main()
    local ui = fu.UIManager
    local disp = bmd.UIDispatcher(ui)

    local win = disp:AddWindow({
        ID = "AudioSelector",
        WindowTitle = "SureBeat by Mansi Visuals",
        Geometry = {100, 100, 800, 550},
        ui:VGroup{
            ID = "root",
            ui:Label{Text = "<b>SureBeat v0.0.2</b>", Alignment = {AlignHCenter = true}, StyleSheet = "font-size: 14px; color: white; padding-bottom: 10px;"},
            ui:Label{Text = "SureBeat helps you edit to the beat of your audio for sure!", Alignment = {AlignHCenter = true }, StyleSheet = "font-size: 16px; color: white;"},
            ui:HGroup{
                ui:Label{Text = "Audio File:", MinimumSize = {80, 30}, Alignment = {AlignRight = true}, StyleSheet = "font-size: 14px; color: white;"},
                ui:LineEdit{ID = "FilePath", Text = "No file selected", ReadOnly = true, MinimumSize = {500, 30}, StyleSheet = "font-size: 14px; color: #555; background-color: #f8f9fa; padding: 10px; border-radius: 5px;"},
                ui:Button{ID = "Browse", Text = "Browse", MinimumSize = {100, 30}, StyleSheet = "background-color: #DEC091; color: black; font-weight: bold; font-size: 14px; border-radius: 5px;"},
            },
            ui:HGroup{
                ui:CheckBox{ID = "AddTransients", Text = "Add Transient Markers (Red Markers)", Checked = true, StyleSheet = "color: white; font-size: 14px;"},
                ui:CheckBox{ID = "AddTempo", Text = "Add Tempo Markers (Cream/White Markers)", Checked = false, StyleSheet = "color: white; font-size: 14px;"},
            },
            ui:HGroup{
                ui:Button{ID = "Analyze", Text = "Analyze", MinimumSize = {130, 30}, StyleSheet = "background-color: #DEC091; color: black; font-weight: bold; font-size: 14px; border-radius: 5px;"},
                ui:Button{ID = "CreateMarkers", Text = "Create Markers", MinimumSize = {130, 30}, StyleSheet = "background-color: #DEC091; color: black; font-weight: bold; font-size: 14px; border-radius: 5px;"},
            },
            ui:TextEdit{
                ID = "InfoDisplay",
                Text = "Status: Awaiting analysis.",
                ReadOnly = true,
                MinimumSize = {400, 60},
                StyleSheet = "color: #333; font-size: 14px; background-color: #f8f9fa; padding: 10px; border-radius: 5px;",
            },
            ui:Label{
                Text = "Crafted for DaVinci Resolve by Mansi Visuals with the help of ChatGPT",
                Alignment = {AlignHCenter = true},
                StyleSheet = "font-size: 16px; color: white; padding-top: 15px;",
            },
            ui:HGroup{
                ui:Button{
                    ID = "BuyCoffee", 
                    Text = "Buy Me A Coffee", 
                    MinimumSize = {130, 25}, 
                    StyleSheet = "background-color: #DEC091; color: black; font-weight: bold; font-size: 12px; border-radius: 5px;",
                }
            },
            ui:Label{
                Text = "SureBeat is a passion project and maintained in my free time, so please consider donating if you like it.",
                Alignment = {AlignHCenter = true},
                StyleSheet = "font-size: 10px; color: gray; padding-top: 5px;"
            },
        },
    })

    local audio_path = ""
    local audio_file_name = ""

    function BrowseButtonClicked()
        local file_path = fusion:RequestFile("Select Audio File", "~/Downloads", "*.wav;*.mp3")
        if file_path then
            audio_file_name = file_path:match("([^/]+)$")
            win:GetItems().FilePath:SetText(audio_file_name)
            audio_path = file_path:lower():find("%.wav$") and file_path or convert_to_wav(file_path)
            win:GetItems().InfoDisplay:SetText("Selected file: " .. audio_file_name)
            print("Audio file selected:", audio_file_name)
        end
    end

    function AnalyzeButtonClicked()
        if audio_path == "" then
            win:GetItems().InfoDisplay:SetText("Please select an audio file.")
            print("Error: No audio file selected.")
            return
        end

        print("Analyzing audio file. This may take some time depending on file length.")
        win:GetItems().InfoDisplay:SetText("Analyzing Audio... Please Wait...")
        local transients_detected = detect_transients_with_aubioonset(audio_path)
        analyze_tempo(audio_path)
        win:GetItems().Analyze.Text = "Re-Analyze"
        if transients_detected or tempo_bpm > 0 then
            win:GetItems().InfoDisplay:SetText("Analysis complete. Ready to create markers.")
            print("Audio analysis completed. Transients detected:", transients_detected, "BPM detected:", tempo_bpm)
        else
            win:GetItems().InfoDisplay:SetText("Analysis failed.")
            print("Error: Analysis failed.")
        end
    end

    function CreateMarkersButtonClicked()
        if #transients == 0 and tempo_bpm == 0 then
            win:GetItems().InfoDisplay:SetText("Please analyze audio before creating markers.")
            print("Error: No analysis data to create markers.")
            return
        end

        local add_transients = win:GetItems().AddTransients.Checked
        local add_tempo = win:GetItems().AddTempo.Checked
        if not add_transients and not add_tempo then
            win:GetItems().InfoDisplay:SetText("Please select at least one marker type.")
            print("Error: No marker type selected.")
            return
        end

        print("Creating markers based on selected options...")
        win:GetItems().InfoDisplay:SetText("Creating markers...")
        if add_markers(win, audio_file_name, add_transients, add_tempo) then
            win:GetItems().CreateMarkers.Text = "Markers Created"
            win:GetItems().InfoDisplay:SetText("Markers created successfully.")
            print("Markers successfully created.")
        else
            win:GetItems().InfoDisplay:SetText("Failed to create markers. Could not find matching audio clip on the timeline.")
            print("Error: Failed to create markers, audio clip not found on timeline.")
        end
    end

    -- Function to open the Buy Me a Coffee link
    function OpenCoffeeLink()
        print("Opening Buy Me a Coffee link...")
        os.execute('open "https://ko-fi.com/surebeat"')
    end

    -- Link button actions to their respective functions
    win.On.Browse.Clicked = BrowseButtonClicked
    win.On.Analyze.Clicked = AnalyzeButtonClicked
    win.On.CreateMarkers.Clicked = CreateMarkersButtonClicked
    win.On.BuyCoffee.Clicked = OpenCoffeeLink

    win.On[win.ID].Close = function(ev)
        print("Closing SureBeat plugin UI...")
        disp:ExitLoop()
    end

    win:Show()
    disp:RunLoop()
    win:Hide()
    print("SureBeat plugin terminated.")
end

main()
