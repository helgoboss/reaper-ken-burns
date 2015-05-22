-- Parameters

slide_length = 5
crossfade_length = 1

min_zoom_factor = 0
max_zoom_factor = 1
min_zoom_shape = 0
max_zoom_shape = 0
min_zoom_tension = 0
max_zoom_tension = 0
zoom_out = false
alternate_zoom = true

min_x_pos = -1
max_x_pos = 1
min_x_shape = 0
max_x_shape = 0
min_x_tension = 0
max_x_tension = 0
pan_left = false
alternate_x_pan = true

min_y_pos = -1
max_y_pos = 1
min_y_shape = 0
max_y_shape = 0
min_y_tension = 0
max_y_tension = 0
pan_up = false
alternate_y_pan = true

rearrange_items = true
redraw_envelopes = true
replace_take_fx_chain = false
replace_ken_burns_fx = false


-- Functions

function is_inverse_direction(alternate, inverse_first, i)  
  if alternate then
    return (i % 2 == (inverse_first and 0 or 1))
  else
    return inverse_first
  end
end

function set_envelope(arg)
  local min_point_idx = arg.inverse and 1 or 0
  local max_point_idx;
  if arg.inverse then 
    max_point_idx = 0
  else
    max_point_idx = 1
  end
  local min_point_pos = arg.inverse and arg.item_length or 0
  local max_point_pos;
  if arg.inverse then 
    max_point_pos = 0
  else
    max_point_pos = arg.item_length
  end
  reaper.SetEnvelopePoint(arg.env, min_point_idx, min_point_pos, arg.min_value, arg.min_shape, arg.min_tension)
  reaper.SetEnvelopePoint(arg.env, max_point_idx, max_point_pos, arg.max_value, arg.max_shape, arg.max_tension)
end

-- Main
local track = reaper.GetSelectedTrack(0, 0)
local items = reaper.CountTrackMediaItems(track)

local ken_burns_fx_chunk = [[
<VIDEO_EFFECT "Video processor" "Ken Burns"
<CODE
|//@param1:zoom 'Zoom' 0 -10 10 0
|//@param2:x_pos 'X Position' 0 -1 1 0
|//@param3:y_pos 'Y Position' 0 -1 1 0
|
|// Normalize parameters
|zoom_factor = 10 ^ (zoom / 10); // 0 to 10
|x_pos_normalized = (x_pos + 1) / 2; // 0 to 1
|y_pos_normalized = (y_pos + 1) / 2; // 0 to 1
|
|// Scale picture to completely fill available space
|gfx_img_info(0, img_width, img_height);
|width_factor = project_w / img_width;
|height_factor = project_h / img_height;
|scale_factor = max(width_factor, height_factor);
|scaled_width = scale_factor * img_width;
|scaled_height = scale_factor * img_height;
|
|// Apply zoom factor
|dest_width = scaled_width * zoom_factor;
|dest_height = scaled_height * zoom_factor;
|
|// Allow panning within image
|supernatant_width = (scaled_width - project_w) + project_w * (zoom_factor - 1);
|x = -x_pos_normalized * supernatant_width;
|supernatant_height = (scaled_height - project_h) + project_h * (zoom_factor - 1);
|y = -y_pos_normalized * supernatant_height;
|
|// Paint
|gfx_blit(0, 1, x | 0, y | 0, dest_width, dest_height); 
>
CODEPARM 0.0000000000 0.0000000000 0.0000000000 -1.0000000000 0.0000000000 0.0000000000 0.0000000000 1.0000000000 122.0000000000 98.0000000000 0.0000000000 0.0000000000 0.0000000000 0.0000000000 0.0000000000 0.0000000000
> 
]]

local parm_env_chunk = [[
<PARMENV 0 -10 10 0
ACT 1
VIS 1 1 1
LANEHEIGHT 0 0
ARM 1
DEFSHAPE 0 -1 -1
PT 0 0 0
PT 4 1 0 0 1
>
<PARMENV 1 -1 1 0
ACT 1
VIS 1 1 1
LANEHEIGHT 0 0
ARM 1
DEFSHAPE 0 -1 -1
PT 0 0 0
PT 4 1 0 0 1
>
<PARMENV 2 -1 1 0
ACT 1
VIS 1 1 1
LANEHEIGHT 0 0
ARM 1
DEFSHAPE 0 -1 -1
PT 0 0 0
PT 4 1 0 0 1
>
]]

local complete_ken_burns_fx_chunk = [[
BYPASS 0 0 0
]] .. ken_burns_fx_chunk .. [[
FLOATPOS 0 0 0 0
FXID {D1D6A6F6-1ADA-4B95-A720-30E22796C0C9}
]] .. parm_env_chunk .. [[
WAK 0
]]

local take_fx_chain_chunk = [[
<TAKEFX
WNDRECT 444 87 870 538
SHOW 0
LASTSEL 0
DOCKED 0
]] .. complete_ken_burns_fx_chunk .. [[
>
]]

for i = 0, items - 1 do
  -- Prepare
  local item = reaper.GetTrackMediaItem(track, i)
  
  -- Setup item FX and envelopes if necessary
  local ok, item_chunk = reaper.GetItemStateChunk(item, "", true)
  local has_take_fx_chain = item_chunk:find("<TAKEFX")
  if has_take_fx_chain then
    -- Take FX chain already there
    if replace_take_fx_chain then
      -- Replace existing take FX chain
      local chunk1, chunk2 = item_chunk:match("(.*)<TAKEFX.-\nWAK 0\n>\n(.*)")
      local new_chunk = chunk1 .. take_fx_chain_chunk .. chunk2
      reaper.SetItemStateChunk(item, new_chunk, false)
    else
      -- Don't replace existing take FX chain
      local ken_burns_fx_start = [[<VIDEO_EFFECT "Video processor" "Ken Burns"]]
      local has_ken_burns_fx = item_chunk:find(ken_burns_fx_start)
      
      if has_ken_burns_fx then      
        -- Ken Burns FX already there 
        if replace_ken_burns_fx then
          -- Replace existing Ken Burns FX
          local chunk1, chunk2 = item_chunk:match("(.*)" .. ken_burns_fx_start .. ".-\n>\n.-\n>\n(.*)")
          local new_chunk = chunk1 .. ken_burns_fx_chunk .. chunk2
          reaper.SetItemStateChunk(item, new_chunk, false)
        end
      else
        -- No Ken Burns FX yet. Find gap to insert it.
        local chunk1, chunk2 = item_chunk:match("(.*<TAKEFX\n.-\nDOCKED.-\n)(.*)")
        local new_chunk = chunk1 .. complete_ken_burns_fx_chunk .. chunk2
        reaper.SetItemStateChunk(item, new_chunk, false)
      end
    end
  else
    -- No take FX chain yet. Find gap to insert it.
    local chunk1, chunk2 = item_chunk:match("(.-\n>\n)(.*)")
    local new_chunk = chunk1 .. take_fx_chain_chunk .. chunk2
    reaper.SetItemStateChunk(item, new_chunk, false)
  end   
  
  if rearrange_items then
    -- Set item length
    local item_length = slide_length
    reaper.SetMediaItemLength(item, item_length, true)
    
    -- Set item fade lengths
    reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0)
    reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0)
    if i > 0 then
      reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", crossfade_length)
    end
    if i < items - 1 then
      reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", crossfade_length)
    end
    
    -- Set item position
    local item_pos
    if i > 0 then
      item_pos = previous_item_end_pos - crossfade_length
      reaper.SetMediaItemPosition(item, item_pos, true)
    else
      item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") 
    end
    previous_item_end_pos = item_pos + item_length
  end
  
  -- Prepare envelopes
  local take = reaper.GetActiveTake(item)
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  
  if redraw_envelopes then
    -- Set zoom envelope
    set_envelope {
      env = reaper.GetTakeEnvelope(take, 0),
      inverse = is_inverse_direction(alternate_zoom, zoom_out, i),
      item_length = item_length,
      min_value = min_zoom_factor,
      max_value = max_zoom_factor,
      min_shape = min_zoom_shape,
      max_shape = max_zoom_shape,
      min_tension = min_zoom_tension,
      max_tension = max_zoom_tension
    }
    
    -- Set x position envelope
    set_envelope {
      env = reaper.GetTakeEnvelope(take, 1),
      inverse = is_inverse_direction(alternate_x_pan, pan_left, i),
      item_length = item_length,
      min_value = min_x_pos,
      max_value = max_x_pos,
      min_shape = min_x_shape,
      max_shape = max_x_shape,
      min_tension = min_x_tension,
      max_tension = max_x_tension
    }
    
    -- Set y Position envelope  
    set_envelope {
      env = reaper.GetTakeEnvelope(take, 2),
      inverse = is_inverse_direction(alternate_y_pan, pan_up, i),
      item_length = item_length,
      min_value = min_y_pos,
      max_value = max_y_pos,
      min_shape = min_y_shape,
      max_shape = max_y_shape,
      min_tension = min_y_tension,
      max_tension = max_y_tension
    }
  end
end
