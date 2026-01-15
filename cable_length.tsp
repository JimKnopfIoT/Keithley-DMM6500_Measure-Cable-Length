--[[
    Cable Tester v9.0 - AWG Selection with Dropdown Lists
    Based on AWG-Tabelle.csv data
    Simplified user interface with predefined selections
]]--

-- AWG Data from AWG-Tabelle.xlsx (Starting from row 17 - AWG 1)
-- Includes metric equivalents for European cables where available
local AWG_DATA = {
    [1] = {mm2 = 42.41, metric_eq = "50", res_per_km = 0.431},
    [2] = {mm2 = 33.62, metric_eq = "35", res_per_km = 0.544},
    [3] = {mm2 = 26.67, metric_eq = nil, res_per_km = 0.686},
    [4] = {mm2 = 21.15, metric_eq = "25", res_per_km = 0.865},
    [5] = {mm2 = 16.77, metric_eq = nil, res_per_km = 1.09},
    [6] = {mm2 = 13.30, metric_eq = "16", res_per_km = 1.38},
    [7] = {mm2 = 10.55, metric_eq = nil, res_per_km = 1.70},
    [8] = {mm2 = 8.367, metric_eq = "10", res_per_km = 2.14},
    [9] = {mm2 = 6.631, metric_eq = nil, res_per_km = 2.70},
    [10] = {mm2 = 5.261, metric_eq = "6", res_per_km = 3.41},
    [11] = {mm2 = 4.17, metric_eq = nil, res_per_km = 4.3},
    [12] = {mm2 = 3.31, metric_eq = "4", res_per_km = 12.90},  -- Calibrated: 9.28m cable measured 0.2395Ohm
    [13] = {mm2 = 2.63, metric_eq = nil, res_per_km = 6.82},
    [14] = {mm2 = 2.08, metric_eq = "2.5", res_per_km = 8.6},
    [15] = {mm2 = 1.65, metric_eq = nil, res_per_km = 10.9},
    [16] = {mm2 = 1.31, metric_eq = "1.5", res_per_km = 13.1},  -- Calibrated: 7m cable measured 0.184Ohm
    [17] = {mm2 = 1.04, metric_eq = nil, res_per_km = 17.3},
    [18] = {mm2 = 0.823, metric_eq = "1", res_per_km = 21.9},
    [19] = {mm2 = 0.653, metric_eq = "0.75", res_per_km = 27.4},
    [20] = {mm2 = 0.519, metric_eq = "0.75", res_per_km = 34.8},
    [21] = {mm2 = 0.412, metric_eq = "0.5", res_per_km = 43.6},
    [22] = {mm2 = 0.324, metric_eq = "0.34", res_per_km = 55.2},
    [23] = {mm2 = 0.259, metric_eq = nil, res_per_km = 69.2},
    [24] = {mm2 = 0.205, metric_eq = "0.25", res_per_km = 87.7},
    [25] = {mm2 = 0.162, metric_eq = nil, res_per_km = 111},
    [26] = {mm2 = 0.128, metric_eq = "0.14", res_per_km = 140},
    [27] = {mm2 = 0.1024, metric_eq = nil, res_per_km = 179},
    [28] = {mm2 = 0.0804, metric_eq = "0.09", res_per_km = 222},
}

-- Cable types with typical capacitance values
local CABLE_TYPES = {
    -- Power Cables (calibrated with 7m test cable: 693.2pF measured)
    ["Power Cu"] = {cap_per_m = 99e-12, desc = "Power cable", category = "Power"},

    -- Speaker Wires (calibrated with 9.28m test cable: 576.8pF measured)
    ["Speaker"] = {cap_per_m = 62.16e-12, desc = "Speaker cable", category = "Speaker"},

    -- Twisted Pair (TP)
    ["Cat5e"] = {cap_per_m = 52e-12, desc = "Ethernet Cat5e", category = "TP"},
    ["Cat6"] = {cap_per_m = 52e-12, desc = "Ethernet Cat6", category = "TP"},
    ["Cat7"] = {cap_per_m = 50e-12, desc = "Ethernet Cat7", category = "TP"},

    -- Coaxial
    ["RG-58"] = {cap_per_m = 101e-12, desc = "Coax 50Ohm", category = "Coax"},
    ["RG-6"] = {cap_per_m = 67e-12, desc = "Coax 75Ohm", category = "Coax"},
    ["RG-59"] = {cap_per_m = 67e-12, desc = "Coax 75Ohm", category = "Coax"},
}

-- Current configuration (will be set by user)
local AWG = 11
local CABLE_TYPE = "Power Cu"
local CAP_PER_M = 60e-12
local RES_PER_M = 0.0043  -- Will be set from AWG_DATA

-- CABLE-SPECIFIC RESISTANCE CORRECTION
-- This offset compensates for contact resistance, solder joints, connectors, etc.
-- It is subtracted from the measured resistance before calculating cable length.
-- Calibrated with 7.0m test cable: adjusted to match capacitance measurement
-- Base resistance formula: R = 2 * RES_PER_M * Length (factor 2 for two-wire measurement)
-- NOTE: This is a CALIBRATION value specific to this cable/setup, NOT a change to AWG specs
-- Calibration history: 0.026 (bad contact) -> 0.015 -> 0.0 (after fixing contact)
local CABLE_RES_OFFSET = 0.0  -- Ohm - subtract from measured resistance

-- UI elements
local ui = {}

-- Save initial system state to restore at exit
local initial_measure_func = dmm.measure.func
local initial_screen = display.SCREEN_HOME  -- Assume we start from home

-- Simple success beep
function success_beep()
    beeper.beep(0.1, 1200)
end

-- Helper function: Format number with German decimal separator (comma instead of dot)
function format_german(num, decimals)
    local fmt = string.format("%%.%df", decimals)
    local str = string.format(fmt, num)
    return string.gsub(str, "%.", ",")
end

-- Configuration screen with dropdown selections
function config_screen()
    display.clear()
    ui.config = display.create(display.ROOT, display.OBJ_SCREEN, "Cable Configuration")

    -- Header
    display.create(ui.config, display.OBJ_TEXT, 250, 30, "CABLE CONFIGURATION", 0xFFFFFF, display.FONT_LARGE)

    -- Cable Type Selection
    display.create(ui.config, display.OBJ_TEXT, 30, 70, "Cable Type:", 0x00FFFF, display.FONT_MEDIUM)
    ui.cable_select = display.create(ui.config, display.OBJ_EDIT_OPTION, 30, 100,
        " ", " ",
        "Power Cu", "Speaker", "Cat5e", "Cat6", "Cat7", "RG-58", "RG-6", "RG-59")

    -- AWG Selection
    display.create(ui.config, display.OBJ_TEXT, 30, 190, "Wire Gauge (AWG / mm2 / metric):", 0x00FFFF, display.FONT_MEDIUM)
    ui.awg_select = display.create(ui.config, display.OBJ_EDIT_OPTION, 30, 220,
        " ", " ",
        "AWG 10 (5.3/6)", "AWG 12 (3.3/4)", "AWG 14 (2.1/2.5)",
        "AWG 16 (1.3/1.5)", "AWG 18 (0.82/1)", "AWG 20 (0.52/0.75)",
        "AWG 22 (0.32/0.34)", "AWG 24 (0.21/0.25)", "AWG 26 (0.13/0.14)")

    -- Info text
    display.create(ui.config, display.OBJ_TEXT, 30, 320, "Power, Speaker, TP (Cat5e/6/7), Coax (RG-58/6/59)", 0xFFFFFF, display.FONT_SMALL)

    -- Start and Exit buttons (X max 650 for display)
    ui.start_btn = display.create(ui.config, display.OBJ_BUTTON, 450, 350, "START")
    ui.exit_btn = display.create(ui.config, display.OBJ_BUTTON, 600, 350, "Exit")

    display.changescreen(ui.config)

    -- Wait for START button with timeout (max 10 minutes = 600 seconds)
    local max_wait_time = 600
    local elapsed_time = 0

    while elapsed_time < max_wait_time do
        local id, result = display.waitevent(1)  -- 1 second timeout

        if id == ui.exit_btn then
            print("Exit button pressed - ending script")
            return false  -- Signal: User wants to exit
        elseif id == ui.start_btn then
            -- Read selections from dropdowns
            local awg_selection = display.getvalue(ui.awg_select)
            local cable_selection = display.getvalue(ui.cable_select)

            -- Parse AWG number from selection
            -- The selection returns 1-9 for the options (reduced list)
            local awg_map = {
                [1]=10, [2]=12, [3]=14, [4]=16, [5]=18,
                [6]=20, [7]=22, [8]=24, [9]=26
            }
            AWG = awg_map[awg_selection] or 12

            -- Get cable type name from selection (1-8)
            local cable_map = {
                [1]="Power Cu",    -- Power Cable
                [2]="Speaker",     -- Speaker Wire
                [3]="Cat5e",       -- Twisted Pair
                [4]="Cat6",        -- Twisted Pair
                [5]="Cat7",        -- Twisted Pair
                [6]="RG-58",       -- Coaxial
                [7]="RG-6",        -- Coaxial
                [8]="RG-59"        -- Coaxial
            }
            CABLE_TYPE = cable_map[cable_selection] or "Power Cu"

            -- Set parameters from tables
            if AWG_DATA[AWG] then
                RES_PER_M = AWG_DATA[AWG].res_per_km / 1000  -- Convert Ohm/km to Ohm/m
            end

            if CABLE_TYPES[CABLE_TYPE] then
                CAP_PER_M = CABLE_TYPES[CABLE_TYPE].cap_per_m
            end

            success_beep()
            return true  -- Signal: START pressed, continue with test
        end

        elapsed_time = elapsed_time + 1
        delay(0.1)
    end

    -- Timeout reached
    print("Config screen timeout - script ending")
    return false  -- Signal: Timeout, exit script
end

function create_results_screen(cap, r_short, length_cap, length_res, avg, diff, diff_pct)
    display.clear()
    ui.screen = display.create(display.ROOT, display.OBJ_SCREEN, "Cable Test Results")

    -- Header (no lines!)
    display.create(ui.screen, display.OBJ_TEXT, 260, 50, "CABLE TEST RESULTS", 0xFFFFFF, display.FONT_LARGE)

    -- Measured Capacitance
    display.create(ui.screen, display.OBJ_TEXT, 30, 100, "Measured Cap:", 0x00FFFF, display.FONT_SMALL)
    display.create(ui.screen, display.OBJ_TEXT, 200, 100, format_german(cap * 1e9, 4) .. " nF", 0xFFFFFF, display.FONT_MEDIUM)

    -- Cable Specs (get from AWG_DATA)
    local mm2 = AWG_DATA[AWG] and AWG_DATA[AWG].mm2 or 0
    local metric_eq = AWG_DATA[AWG] and AWG_DATA[AWG].metric_eq or nil
    local cable_spec
    if metric_eq then
        cable_spec = string.format("AWG %d (%smm2/%s) %s | %spF/m %sOhm/m",
            AWG, format_german(mm2, 1), metric_eq, CABLE_TYPE, format_german(CAP_PER_M * 1e12, 1), format_german(RES_PER_M, 4))
    else
        cable_spec = string.format("AWG %d (%smm2) %s | %spF/m %sOhm/m",
            AWG, format_german(mm2, 1), CABLE_TYPE, format_german(CAP_PER_M * 1e12, 1), format_german(RES_PER_M, 4))
    end
    display.create(ui.screen, display.OBJ_TEXT, 30, 125, cable_spec, 0xFFFF00, display.FONT_SMALL)

    -- LENGTH RESULTS Header
    display.create(ui.screen, display.OBJ_TEXT, 280, 160, "LENGTH RESULTS", 0x00FFFF, display.FONT_MEDIUM)

    -- From Capacitance
    display.create(ui.screen, display.OBJ_TEXT, 30, 200, "From Capacitance:", 0xFFFF00, display.FONT_MEDIUM)
    display.create(ui.screen, display.OBJ_TEXT, 350, 200, format_german(length_cap, 3) .. " m", 0xFFFFFF, display.FONT_LARGE)

    -- From Resistance (show N/A if skipped)
    display.create(ui.screen, display.OBJ_TEXT, 30, 240, "From Resistance:", 0xFFFF00, display.FONT_MEDIUM)
    if length_res ~= nil then
        display.create(ui.screen, display.OBJ_TEXT, 350, 240, format_german(length_res, 3) .. " m", 0xFFFFFF, display.FONT_LARGE)
    else
        display.create(ui.screen, display.OBJ_TEXT, 350, 240, "N/A", 0x808080, display.FONT_LARGE)
    end

    -- Color code the average
    local avg_color = 0x00FF00  -- Green
    if diff_pct ~= nil then
        if diff_pct > 10 then avg_color = 0xFFFF00 end  -- Yellow
        if diff_pct > 20 then avg_color = 0xFF0000 end  -- Red
    end

    -- AVERAGE
    if length_res ~= nil then
        display.create(ui.screen, display.OBJ_TEXT, 30, 290, "AVERAGE:", 0xFFFF00, display.FONT_LARGE)
    else
        display.create(ui.screen, display.OBJ_TEXT, 30, 290, "RESULT:", 0xFFFF00, display.FONT_LARGE)
    end
    display.create(ui.screen, display.OBJ_TEXT, 350, 290, format_german(avg, 3) .. " m", avg_color, display.FONT_LARGE)

    -- Difference (only if resistance was measured) - using SMALL font to save space
    if diff_pct ~= nil then
        display.create(ui.screen, display.OBJ_TEXT, 30, 320, "Diff: " .. format_german(diff_pct, 2) .. "% (" .. format_german(diff, 3) .. "m)", 0xFFFFFF, display.FONT_SMALL)
    else
        display.create(ui.screen, display.OBJ_TEXT, 30, 320, "Resistance skipped", 0x808080, display.FONT_SMALL)
    end

    -- Countdown text (will be updated in main loop) - positioned at bottom
    ui.countdown_text = display.create(ui.screen, display.OBJ_TEXT, 30, 340, "Exit: 180s", 0x808080, display.FONT_SMALL)

    -- Repeat and Exit buttons (Y max is 374, leave some margin)
    ui.repeat_btn = display.create(ui.screen, display.OBJ_BUTTON, 450, 360, "Repeat")
    ui.exit_btn = display.create(ui.screen, display.OBJ_BUTTON, 600, 360, "Exit")

    display.changescreen(ui.screen)

    -- Return button IDs and countdown text for event handling
    return ui.repeat_btn, ui.exit_btn, ui.countdown_text
end

-- Status display - use simple settext
function show_status(line1, line2)
    print(string.format("STATUS: %s - %s", line1, line2 or ""))
    display.clear()
    display.settext(display.TEXT1, string.sub(line1, 1, 20))
    display.settext(display.TEXT2, string.sub(line2 or "", 1, 32))
    display.changescreen(display.SCREEN_USER_SWIPE)
end

function main()
    reset()

    show_status("Cable Test v9", "Starting...")
    success_beep()
    delay(2)

    -- Step 1: Short check with retry
    show_status("TEST 1: Short", "Open cable")
    delay(2)

    dmm.measure.func = dmm.FUNC_RESISTANCE
    dmm.measure.autorange = dmm.ON
    dmm.measure.nplc = 1
    dmm.measure.autozero.enable = dmm.ON
    delay(0.5)

    local r_open = dmm.measure.read()

    -- If shorted, ask user to open cable
    while r_open < 1000 do
        -- Create dialog asking to open cable
        display.clear()
        local short_dialog = display.create(display.ROOT, display.OBJ_SCREEN, "Short Detected")
        display.create(short_dialog, display.OBJ_TEXT, 250, 100, "ERROR: SHORTED!", 0xFF0000, display.FONT_LARGE)
        display.create(short_dialog, display.OBJ_TEXT, 150, 150, string.format("Resistance: %.1f Ohm", r_open), 0xFFFFFF, display.FONT_MEDIUM)
        display.create(short_dialog, display.OBJ_TEXT, 150, 180, "OPEN the cable, then press OK", 0xFFFF00, display.FONT_MEDIUM)
        local retry_btn = display.create(short_dialog, display.OBJ_BUTTON, 350, 250, "OK")
        display.changescreen(short_dialog)

        beeper.beep(0.5, 400)

        -- Wait for OK button with timeout
        local timeout = 0
        while timeout < 120 do  -- Max 120 seconds (2 minutes)
            local id = display.waitevent(1)  -- 1 second timeout to allow EXIT
            if id == retry_btn then
                break
            end
            timeout = timeout + 1
            delay(0.05)
        end

        if timeout >= 120 then
            print("Timeout waiting for user - script ending")
            return  -- Exit main function
        end

        display.delete(short_dialog)

        show_status("TEST 1: Short", "Retry...")
        delay(0.5)
        r_open = dmm.measure.read()
    end

    show_status("Short: PASS", string.format("R>%.0fkOhm", r_open/1000))
    success_beep()
    delay(2)

    -- Step 2: Capacitance
    show_status("TEST 2: Cap", "Measuring...")
    delay(1)

    dmm.measure.func = dmm.FUNC_CAPACITANCE
    dmm.measure.autorange = dmm.ON
    delay(0.5)

    local cap = dmm.measure.read()
    local length_cap = cap / CAP_PER_M

    show_status(string.format("C:%.1fnF", cap * 1e9), string.format("Length: %.1fm", length_cap))
    success_beep()
    delay(3)

    -- Step 3: Resistance - WITH USER PROMPT, VERIFICATION, AND SKIP OPTION

    -- Configure resistance measurement for detection
    dmm.measure.func = dmm.FUNC_RESISTANCE
    dmm.measure.autorange = dmm.ON
    dmm.measure.nplc = 0.1  -- Fast measurement for detection
    dmm.measure.autozero.enable = dmm.OFF
    delay(0.5)

    local r_short = nil
    local length_res = nil
    local keep_trying = true
    local is_shorted = false

    -- Loop: Ask to short, check, repeat if not shorted
    while keep_trying and not is_shorted do
        -- Create dialog screen asking to short far end
        display.clear()
        local dialog = display.create(display.ROOT, display.OBJ_SCREEN, "Resistance Test")
        display.create(dialog, display.OBJ_TEXT, 200, 100, "SHORT FAR END NOW", 0xFFFF00, display.FONT_LARGE)
        display.create(dialog, display.OBJ_TEXT, 150, 150, "Then press OK to measure", 0xFFFFFF, display.FONT_MEDIUM)
        display.create(dialog, display.OBJ_TEXT, 150, 180, "or Cancel to skip", 0xFFFFFF, display.FONT_MEDIUM)
        local ok_btn = display.create(dialog, display.OBJ_BUTTON, 500, 250, "OK")
        local cancel_btn = display.create(dialog, display.OBJ_BUTTON, 650, 250, "Cancel")
        display.changescreen(dialog)

        beeper.beep(0.15, 1000)
        delay(0.2)
        beeper.beep(0.15, 1000)

        -- Wait for button press with timeout
        local user_choice = nil
        local timeout = 0
        while user_choice == nil and timeout < 120 do  -- Max 120 seconds
            local id = display.waitevent(1)  -- 1 second timeout to allow EXIT
            if id == ok_btn then
                user_choice = "OK"
            elseif id == cancel_btn then
                user_choice = "CANCEL"
            end
            timeout = timeout + 1
            delay(0.05)
        end

        if timeout >= 120 then
            print("Timeout waiting for user - skipping resistance measurement")
            user_choice = "CANCEL"  -- Treat timeout as cancel
        end

        display.delete(dialog)

        if user_choice == "CANCEL" then
            -- User wants to skip
            keep_trying = false
        else
            -- User pressed OK - now check if actually shorted
            show_status("TEST 3: Resist", "Checking...")
            delay(0.5)

            local r_test = dmm.measure.read()

            if r_test < 1 then  -- Less than 1 Ohm = properly shorted
                is_shorted = true
                success_beep()  -- Confirmation beep
            else
                -- NOT shorted! Show error and loop will repeat the dialog
                show_status("NOT SHORTED!", string.format("%.0f Ohm", r_test))
                beeper.beep(0.5, 400)
                delay(2)
                -- Loop continues, same dialog will appear again
            end
        end
    end

    -- After the loop: either is_shorted=true or keep_trying=false
    if is_shorted then
        show_status("TEST 3: Resist", "Measuring...")

        -- Switch to accurate measurement
        dmm.measure.nplc = 1
        dmm.measure.autozero.enable = dmm.ON
        delay(0.5)

        r_short = dmm.measure.read()

        -- Apply cable-specific resistance correction (compensates for contact resistance, poor quality cable, etc.)
        -- The AWG resistance value (RES_PER_M) remains unchanged - this is only a measurement correction
        local r_corrected = r_short - CABLE_RES_OFFSET
        length_res = r_corrected / (2 * RES_PER_M)

        show_status(string.format("R:%.2fOhm", r_short), string.format("Length: %.1fm", length_res))
        success_beep()
        delay(3)
    else
        show_status("TEST 3: Resist", "SKIPPED")
        delay(2)
    end

    -- Calculate results (handle skipped resistance measurement)
    local diff, diff_pct, avg

    if length_res ~= nil then
        -- Normal case: both measurements available
        diff = math.abs(length_cap - length_res)
        diff_pct = (diff / length_cap) * 100
        avg = (length_cap + length_res) / 2
    else
        -- Resistance measurement skipped
        diff = nil
        diff_pct = nil
        avg = length_cap  -- Use only capacitance result
    end

    -- Beep feedback (only if both measurements were done)
    if diff_pct ~= nil then
        if diff_pct < 10 then
            -- Double beep for good result
            success_beep()
            delay(0.3)
            success_beep()
        else
            -- Warning beep for bad result
            beeper.beep(0.3, 600)
        end
    else
        -- Single beep if resistance was skipped
        success_beep()
    end

    -- Create and show results screen with all values
    local repeat_btn, exit_btn, countdown_text = create_results_screen(cap, r_short, length_cap, length_res, avg, diff, diff_pct)

    -- Show completion message
    print("\nTest complete. Press Repeat, Exit, or wait 180 seconds...")

    -- Wait for button or timeout (180 seconds = 3 minutes) with countdown
    local timeout_seconds = 180
    local elapsed = 0
    while elapsed < timeout_seconds do
        local remaining = timeout_seconds - elapsed

        -- Update countdown display (only if countdown_text exists)
        if countdown_text ~= nil then
            local countdown_msg
            if remaining > 60 then
                local minutes = math.floor(remaining / 60)
                local seconds = remaining - (minutes * 60)
                countdown_msg = string.format("Exit: %d:%02d", minutes, seconds)
            else
                countdown_msg = string.format("Exit: %ds", remaining)
            end
            display.settext(countdown_text, countdown_msg)
        end

        local id = display.waitevent(1)  -- 1 second timeout
        if id == exit_btn then
            print("\nExit button pressed - ending script")
            return false  -- Signal: Exit, don't repeat
        elseif id == repeat_btn then
            print("\nRepeat button pressed - restarting test")
            return true  -- Signal: Repeat test
        end
        elapsed = elapsed + 1
    end

    print("\nTimeout reached - ending script")
    return false  -- Signal: Timeout, exit
end

-- Run test cycles with Repeat option
local continue = true

while continue do
    -- Show configuration screen
    local start_test = config_screen()

    if not start_test then
        -- User pressed Exit or timeout - end script
        print("Exiting from config screen...")
        break
    end

    -- Run main test
    local repeat_test = main()

    if not repeat_test then
        -- User pressed Exit or timeout - end script
        print("Exiting from results screen...")
        break
    end

    -- If repeat_test is true, loop continues
end

-- Clean exit: restore normal operation when script ends (like cable_tester_complete)
print("")
print("═══════════════════════════════════════")
print("  Cable Tester v9 - Exiting...")
print("═══════════════════════════════════════")

-- Cleanup - restore HOME screen before reset
print("")
print("═══════════════════════════════════════")
print("  Cable Tester v9 - Exiting...")
print("═══════════════════════════════════════")

-- Return to HOME screen BEFORE reset (prevents black screen)
display.changescreen(display.SCREEN_HOME)
delay(5)  -- Wait 5 seconds before reset so user can see the screen

-- Reset to restore normal operation
reset()

print("Exit complete.")
print("NOTE: Device is in IDLE mode - click IDLE → Continuous for measurements")

if not status and err then
    print("Note: " .. tostring(err))
end

print("═══════════════════════════════════════")
print("Cable Tester v9 - Ready to run again")
