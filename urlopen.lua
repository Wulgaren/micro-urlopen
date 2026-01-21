VERSION = "0.0.0"

local micro = import("micro")
local config = import("micro/config")
local shell = import("micro/shell")

function init()
	config.MakeCommand("urlopen", urlopen, config.NoComplete)
	config.TryBindKey("Alt-o", "command:urlopen", true)
end

function urlopen(bp)
	local c = bp.Cursor
	local buf = bp.Buf
	local line = buf:Line(c.Y)

	-- Find all URLs in the line using a more permissive pattern
	-- Matches http:// or https:// followed by URL-valid characters
	-- Stops at whitespace or >, but includes all other valid URL characters
	-- Valid URL chars: alphanumeric, -, _, ., ?, #, @, !, $, &, ', *, +, ,, :, =, ;, ~, /, [, ], (, )
	-- Note: We include ) in the match but will trim it if it looks like a delimiter
	local urlPattern = "https?://[^%s>]+"
	local start, stop = string.find(line, urlPattern)
	
	-- Try to find URL at cursor position by checking all matches
	local found = false
	local result = nil
	local urlStart, urlStop = start, stop
	
	-- Search for URLs in the line, checking if cursor is within any match
	while urlStart do
		-- Check if cursor is within this URL match
		if (c.X >= urlStart - 1) and (c.X <= urlStop - 1) then
			result = string.sub(line, urlStart, urlStop)
			found = true
			break
		end
		-- Find next URL after this one
		urlStart, urlStop = string.find(line, urlPattern, urlStop + 1)
	end
	
	if found and result then
		-- Strip trailing punctuation that's not part of the URL
		-- Remove sentence-ending punctuation: ., ;, :, !, ?
		result = string.gsub(result, "[%.,;:!?]+$", "")
		
		-- Handle closing parentheses/brackets that might be delimiters
		-- Check if there's whitespace, end of line, or certain characters after the URL
		-- This helps with markdown links like [text](url) or URLs in parentheses
		local afterUrl = string.sub(line, urlStop + 1, urlStop + 2)
		local lastChar = string.sub(result, -1)
		
		-- If URL ends with ) or ] and is followed by whitespace/end/punctuation, it's likely a delimiter
		if (lastChar == ")" or lastChar == "]") then
			-- Check if followed by whitespace, end of line, or common delimiters
			if afterUrl == "" or afterUrl == " " or afterUrl == "\t" or 
			   afterUrl == "\n" or afterUrl == ">" or 
			   string.match(afterUrl, "^[%.,;:!?%s]") then
				result = string.sub(result, 1, -2)
			end
		end
		
		-- Ensure we have a valid URL (at least the scheme and domain)
		if string.len(result) > 10 then
			shell.JobSpawn("open", {result}, nil, renameStderr, renameExit, bp)
		else
			micro.InfoBar():Message("Invalid URL")
		end
	else
		micro.InfoBar():Message("Not a link")
	end
end

function renameStderr(err)
    micro.Log(err)
    micro.InfoBar():Message(err)
end

function renameExit(output, args)
    local bp = args[1]
    bp.Buf:ReOpen()
end
