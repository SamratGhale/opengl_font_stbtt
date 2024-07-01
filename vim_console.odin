package main
import im "./odin-imgui"
import      "base:runtime"
import "core:c/libc"
import "core:os"
import "core:c"
import strings "core:strings"
import "core:fmt"

Console :: struct {
	InputBuf       : [^]u8,
	Items          : [dynamic]string,
	ScrollToBottom : bool,

	History        : [dynamic]string,
	HistoryPos     : int,
	Commands       : [dynamic]string,
	filter : im.TextFilter,
}

init_console :: proc(using console: ^Console){
	//using console
	Items      = make([dynamic]string, 0, 10)
	History    = make([dynamic]string, 0, 10)
	Commands   = make([dynamic]string, 0, 10)
    InputBuf   = make([^]u8, 256)

	HistoryPos = -1

	/*
	append(&Commands, "HELP")
	append(&Commands, "HISTORY")
	append(&Commands, "CLEAR")
	append(&Commands, "CLASSIFY")
	*/
	//console_add_log(console, "Welcome to ImGui!")
}

console_add_log :: proc(using console : ^Console, log: string){
	//Probably duplicate the string
	append(&Items, log)
	ScrollToBottom = true
}

console_clear_log :: proc(using console: ^Console){
	clear(&Items)
	ScrollToBottom = true
}

console_draw :: proc(using console: ^Console, title : string, p_open: ^bool){
	im.SetNextWindowSize(im.Vec2{520, 600}, .FirstUseEver)

	if !im.Begin(strings.unsafe_string_to_cstring(title), p_open){
		im.End()
		return
	}

	if im.BeginPopupContextItem(){
		if im.MenuItem("Close") do p_open^ = false
		im.EndPopup()
	}

	//im.TextWrapped("This Example implements a console with basic coloring, completiotion and history")

	//TODO: display items starting from the bottom
    reclaim_focus := true;
    /*
    if im.InputText("Input", cstring(&filter.InputBuf[0]), 256, {.EnterReturnsTrue, .CallbackCompletion, .CallbackHistory}, ConsoleInputTextCallback)
    {
    	/*
    	input_end := string(InputBuf)[len(InputBuf);
    	for (input_end > InputBuf && input_end[-1] == ' ') { 
    		input_end -=1 ; 
    	} 
    	^input_end = 0;
    	*/
    	//if (InputBuf[0])
    	ConsoleExecCommand(console, cstring(InputBuf));
    	libc.strcpy(InputBuf, "");

    	app.vim_state.mode = .Command
    	//reclaim_focus = true;

    }
    */
    // Demonstrate keeping focus on the input box

    /*
	if im.SmallButton("Add dummy text") {
		console_add_log(console, fmt.tprintf("%d some text", len(Items) ))
		console_add_log(console, "some more text")
		console_add_log(console, "display very important message here!")

	}
	im.SameLine()

	if (im.SmallButton("Add Dummy Error")) { 
		console_add_log(console, "[error] something went wrong"); 
	}
	im.SameLine();

	if (im.SmallButton("Clear")) { 
		console_clear_log(console); 
	} 
	im.SameLine();

	copy_to_clipboard : bool = im.SmallButton("Copy"); 
	im.SameLine()

	if im.SmallButton("Scroll to bottom"){
		ScrollToBottom = true
	}
	im.Separator()
	*/


	im.PushStyleVarImVec2(.FramePadding, im.Vec2{0,0})

	im.TextFilter_Draw(&filter, "Filter (\"incl,-excl\") (\"error\")", 180)
    im.SetItemDefaultFocus();
    if reclaim_focus{
        im.SetKeyboardFocusHere(-1); // Auto focus previous widget
    }

	im.PopStyleVar()
	im.Separator()

    footer_height_to_reserve :f32  = im.GetStyle().ItemSpacing.y + im.GetFrameHeightWithSpacing(); 
    // 1 separator, 1 input text

    im.BeginChild("ScrollingRegion", im.Vec2{0, -footer_height_to_reserve},{}, {.HorizontalScrollbar}); // Leave room for 1 separator + 1 InputText


    if im.BeginPopupContextWindow() {
    	if (im.Selectable("Clear")) do console_clear_log(console);
    	im.EndPopup();
    }

    im.PushStyleVarImVec2(.ItemSpacing, im.Vec2{4,1});

    //if (copy_to_clipboard) do im.LogToClipboard();

    col_default_text := im.GetStyleColorVec4(.Text);

    if app.vim_state.mode == .ListFiles{
    	directory := os.get_current_directory()

    	handle, _ := os.open(directory, os.O_RDONLY)

    	files, err := os.read_dir(handle, 20)

    	for file in files{
    		//im.TextUnformatted(strings.unsafe_string_to_cstring(file.name))

            if !im.TextFilter_PassFilter(&filter, strings.unsafe_string_to_cstring(file.name)) do continue
            col := col_default_text

            im.PushStyleColorImVec4(.Text, col[0])
            im.TextUnformatted(strings.unsafe_string_to_cstring(file.name))
            im.PopStyleColor()
    	}

    }

    /*
    for item in Items{
    	if !im.TextFilter_PassFilter(&filter, strings.unsafe_string_to_cstring(item)) do continue

    }
    */

    //if copy_to_clipboard do im.LogFinish()
    //if ScrollToBottom do im.SetScrollHere()

    ScrollToBottom = false
    im.PopStyleVar()
    im.EndChild()
    im.Separator()

    //Command line

    im.End();
}

ConsoleExecCommand :: proc(using console: ^Console, command_line: cstring){
	console_add_log(console, fmt.tprintf("# %s\n", command_line));

}

ConsoleInputTextCallback :: proc "c" (data: ^im.InputTextCallbackData) -> c.int{
    context = runtime.default_context()
	console := cast(^Console)data.UserData
	return ConsoleTextEditCallback(console, data)
}     

ConsoleTextEditCallback :: proc(using console: ^Console,  data: ^im.InputTextCallbackData ) -> c.int{
	//AddLog("cursor: %d, selection: %d-%d", data->CursorPos, data->SelectionStart, data->SelectionEnd);
	/*
        	if  .CallbackCompletion in data.EventFlag {
                // Example of TEXT COMPLETION
                // Locate beginning of current word
                word_start := word_end;

                for(word_start > data->Buf) {

                    c := word_start[-1];
                    if (c == ' ' || c == '\t' || c == ',' || c == ';') do break;
                    word_start-=1;
                }
                // Build a list of candidates
                candidates: [dynamic]cstring = make([dynamic]cstring, 0, 10);

                for command in Commands{
                	if (libc.strncmp(command,  word_start, int(data.Buf)) == 0){
                		append(candidates, command)
                		//candidates.push_back(Commands[i]);
                	}
                }

                if (len(candidates) == 0)
                {
                    // No match
                    console_add_log(console, "No match for \"%.*s\"!\n", (int)(word_end-word_start), word_start);
                }
                else if (candidates.Size == 1)
                {
                    // Single match. Delete the beginning of the word and replace it entirely so we've got nice casing
                    im.InputTextCallbackData_DeleteChars(data, (int)(uintptr(word_start) - uintptr(data.Buf)), (int)(uintptr(word_end)-uintptr(word_start)))

                    //data->InsertChars(data->CursorPos, candidates[0]);

                    im.InputTextCallbackData_InsertChars(data, data.CursorPos, candidates[0])
                    im.InputTextCallbackData_InsertChars(data, data.CursorPos, "")

                    //data->InsertChars(data->CursorPos, " ");
                }
                else
                {
                    // Multiple matches. Complete as much as we can, so inputing "C" will complete to "CL" and display "CLEAR" and "CLASSIFY"
                    match_len : int = (int)(uintptr(word_end) - uintptr(word_start));
                    for (true)
                    {
                        c : int = 0;
                        all_candidates_matches := true;
                        for candidate, i in candidates{
                        	if !all_candidates_matches do break
                            if (i == 0){
                                c = libc.toupper(candidates[i][match_len]);
                            }
                            else if (c == 0 || c != libc.toupper(candidates[i][match_len])){
                                all_candidates_matches = false;
                            }

                        }
                        if (!all_candidates_matches) do break;
                        match_len+=1;
                    }
                    if (match_len > 0) {
                    	im.InputTextCallbackData_DeleteChars(data, (int)(uintptr(word_start) - uintptr(data.Buf)), (int)(uintptr(word_end)-uintptr(word_start)))
                        //data->DeleteChars((int)(word_start - data->Buf), (int)(word_end-word_start));
                        im.InputTextCallbackData_InsertChars(data, data->CursorPos, candidates[0], candidates[match_len])
                        //data->InsertChars(data->CursorPos, candidates[0], candidates[0] + match_len);
                    }
                    // List matches
                    console_add_log(console,"Possible matches:\n");

                    for candidate in candidates{
                        console_add_log(console, fmt.tprintf("- %s\n", candidate));
                    }
                }
                break;
            }
        if .CallbackHistory in data.EventFlag{
                // Example of HISTORY
                prev_history_pos :int= HistoryPos;
                if (data.EventKey == .UpArrow)
                {
                    if (HistoryPos == -1){
                        HistoryPos = History.Size - 1;
                    }
                    else if (HistoryPos > 0){
                        HistoryPos+=1;
                    }
                }
                else if (data.EventKey == .DownArrow)
                {
                    if (HistoryPos != -1){
                    	HistoryPos+=1
                        if (HistoryPos >= History.Size){
                            HistoryPos = -1;
                        }
                    }
                }
                // A better implementation would preserve the data on the current input line along with cursor position.
                if (prev_history_pos != HistoryPos)
                {
                	data.BufTextLen = cast(int)fmt.snprintf(data.Buf, i32(data.BufSize), "%s", (HistoryPos >= 0) ? History[HistoryPos] : "")
                    data.CursorPos = data.BufTextLen 
                    data.SelectionStart = data.BufTextLen 
                    data.SelectionEnd = data.BufTextLen 
                    data.BufDirty = true
                }
            }
        return 0;
        */
        return 0
}
















