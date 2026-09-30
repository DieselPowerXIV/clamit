--[[ Ashita v4 Addons Notes
    -   The main addon information table has been renamed to just 'addon'.
    -   The main addon information table now has two additional (optional) fields 'desc' and 'link'.
    -   The main addon information table has two hidden properties 'instance' and 'path'.
        -> instance is a class object of the current addon instance. This object has the following members:
            -> addon.instance.state                 - Returns the addons current state.
            -> addon.instance.current_frame         - Returns the addons current frame count.
            -> addon.instance.get_memory_usage()    - Returns the addons current memory usage.
        -> path is the path to the addons root folder.
    -   The main addon information table is no longer read-only; you are free to add other custom fields to it if you wish.
--]]
addon.name      = 'clamit';
addon.author    = 'DieselPowerXIV';
addon.version   = '1.0';
addon.desc      = 'Another (over-engineered) Clamming tracker.';
addon.link      = 'https://github.com/DieselPowerXIV/clamit';

require('common');
local chat = require('chat');
local d3d8 = require('d3d8');
local ffi = require('ffi');
--local fonts = require('fonts');
local imgui = require('imgui');
local settings = require('settings');
local data = require('constants');

 --local C = ffi.C;
local d3d8dev = d3d8.get_device();

--[[
	There's a lot of things that imgui expects to be in a table/array, so let's just put most stuff into a table... [It's so annoying...]
--]]
local default_settings = T { -- The initial data structure for what we are going to use for the addon.
	general = T { -- General settings.
		advanced = T {false}, -- Show advanced settings in the config?
		easter_eggs = T {true}, -- Hiddden behind advanced, will disable the haha's and wow's.
		verbose = T {false}, -- Show extra messages about things that happen?
		clear_bucket = T {false}, -- Clear bucket on load.
		clear_session = T {false}, -- Clear session on load.
		out_of_area = T {false}, -- Show the bucket / stats outside of Bibiki Bay?
		session_stats = T {false}, -- Show some item/bucket counts in the session section of the bucket window.
		logging = T { -- Are we logging things?
			enabled = T {false},
			log_type = T {1}, -- What are we logging?
		},
		autosave = T {
			bucket = T {true}, -- Save with a new bucket.
			turnin = T {true}, -- Save when tturning in a bucket.
			broken = T {true}, -- Save when the bucket breaks.
			item = T {true}, -- Save after a certain number of items.
			item_count = T {10}, -- How many items before saving.
		},
		bucket = T {
			cost = T {500}, -- Price to get a bucket. Shouldn't ever change, but if the NPC tells us a different number, we'll update it on the fly...
			capacity = T {50}, -- Capacity per bucket upgrade. Not likely to ever change, but if it does, this will make it easier to fix... (or put in server specific modifications...)
			subtract_cost = T {true}, -- Subtract bucket price from session value displays? (Not applied to lost bucket value, or 'highest value' tracking)
			vendor_value_low = T {true}, -- Use the lower vendor values for calculations?
			hide_out_of_area = T {false}, -- Do we want to hide the tracking / bucket window if we're not in bibiki bay?
		},
	}, -- END general
	display = T { -- Display related settings.
		config_window = T { -- The config menus.
			visible = T {false}, -- Is this window being displayed right now?
			timeout = T {600},
			opacity = T {1.0},
			padding = T {1.0},
			scale = T {1.0},
			font_scale = T {1.0},
			font_color = T {1.0, 1.0, 1.0, 1.0},
			disabled_color = T {0.6, 0.6, 0.6, 1.0},
			tab = 1, -- The current config tab.
		},
		bucket_window = T { -- The bucket tracker.
			visible = T {false}, -- Is this window being displayed right now?
			timeout = T {600},
			opacity = T {1.0},
			padding = T {1.0},
			scale = T {1.0},
			font_scale = T {1.0},
			font_color = T {1.0, 1.0, 1.0, 1.0},
			disabled_color = T {0.6, 0.6, 0.6, 1.0},
		},
	}, -- END display
	weights = T { -- For changing color display based on weight
		enabled 	= T {true}, -- Show things in colors based on the bucket weight.
		super_low	= T {35}, -- First weight threshold: heaviest item is Igneous Rock.
		low			= T {20}, -- Second weight threshold: next heaviest item is Tropical Clam.
		mid			= T {11}, -- Third weight threshold: next heaviest item is Jacknife.
		high		= T {7}, -- Fourth weigh threshold: next heaviest items are Pebble and White Sand.
		full		= T {5}, -- No fifth weight bracket since it's only off by 1, and no sixth since the bucket already counts as full then.
		colors = T {
			default		= T {1.0, 1.0, 1.0, 1.0},
			super_low	= T {0.7, 1.0, 0.7, 1.0},
			low			= T {1.0, 1.0, 0.0, 1.0},
			mid			= T {1.0, 0.5, 0.0, 1.0},
			high		= T {1.0, 0.0, 0.0, 1.0},
			full		= T {0.8, 0.4, 1.0, 1.0},
		},
	}, -- END weights
	values = T { -- For changing color display based on values. Sub sections for: Item, Bucket and Session.
		items = T {
			enabled		= T {true}, -- Show item's in colors based on their value.
			super_low	= T {5},
			low			= T {1000},
			mid			= T {2000},
			high		= T {5000},
			colors = T {
				default		= T {1.0, 1.0, 1.0, 1.0},
				super_low	= T {0.6, 0.6, 0.6, 1.0}, -- For very low or no value items
				low			= T {1.0, 1.0, 0.0, 1.0},
				mid			= T {0.0, 1.0, 0.0, 1.0},
				high		= T {0.8, 0.4, 1.0, 1.0},
			},
		},
		bucket = T {
			enabled		= T {true}, -- Show bucket values in colors based on said value.
			super_low	= T {0},
			low			= T {1000},
			mid			= T {2000},
			high		= T {5000},
			colors = T {
				default		= T {1.0, 1.0, 1.0, 1.0},
				super_low	= T {1.0, 0.0, 0.0, 1.0}, -- For negative values.
				low			= T {1.0, 1.0, 0.0, 1.0},
				mid			= T {0.0, 1.0, 0.0, 1.0},
				high		= T {0.8, 0.4, 1.0, 1.0},
			},
		},
		session = T {
			enabled		= T {true}, -- Show session values in colors based on said value.
			super_low	= T {0},
			low			= T {25000},
			mid			= T {50000},
			high		= T {100000},
			colors = T {
				default		= T {1.0, 1.0, 1.0, 1.0},
				super_low	= T {1.0, 0.0, 0.0, 1.0}, -- For negative values.
				low			= T {1.0, 1.0, 0.0, 1.0},
				mid			= T {0.0, 1.0, 0.0, 1.0},
				high		= T {0.8, 0.4, 1.0, 1.0},
			},
		},
	}, -- END values
	bucket = T { -- Bucket contents tracking
		active = false, -- Do we currently have a bucket?
		broken = false, -- Is it broken?
		zoned = false, -- Was there a zone change while holding this bucket?
		items = T {
			total = 0, -- How many items are in it?
			unique = 0, -- How many unique items are in it?
		},
		weight = 0, -- How much weight is in it?
		capacity = 0, -- Updated from the log when a bucket is purchased or upgraded. Reset back to 0 on turn-in.
		contents = T {}, -- The things that get dug up. Log name as key, count as data.
	},
	session = T {
		start_time = 0, -- Update to system time when we take the first action of a new session. (Session reset should set this back to 0 so we can tell when we're doing the first action).
		items = T {
			total = 0, -- Total items dug up in this session.
			gained = 0, -- Total number of items gained in this session.
			lost = 0, -- Total number of items lost in this session.
			unique = 0, -- How many unique items found in this session.
		},
		buckets = T {
			total = 0, -- Number of buckets in this session.
			breaks = 0, -- Number of breaks in this session.
			upgrades = 0, -- Number of times a bucket has been upgraded in this session.
			turnins = 0, -- Number of buckets successfully turned in.
		},
		gained = T {}, -- All the items gained this session. Log name as key, count as data. (For showing a list if wanted, and calculating value).
		lost = T {}, -- All the items lost this session. Log name as key, count as data. (For showing a list if wanted, and calculating value).
	},
	dig_timer = T {
		count = 10, -- We'll need to dynamically set to 10 if countdown is true, or 0 if false.
		interval = 10, -- Delay between digs in the game. Should never need to be updated...
		countdown = T {true}, -- Does the dig counter display counting down? (IDK why anyone would want it to count up?)
		color = T {0.0, 1.0, 0.0, 1.0}, -- Font color to use when the timer is ready. Default is green.
	},
--[[
		Sound Attributions:
		[File]:		[URL where applicable]
		dig_1:		https://freesound.org/people/dland/sounds/320181/
		dig_2:		https://freesound.org/people/finix473/sounds/546974/
		dig_3:		https://freesound.org/people/ertfelda/sounds/243701/
		dig_4:		https://freesound.org/people/Aesnas/sounds/812555/
		dig_5:		https://freesound.org/people/Degrant3814/sounds/631901/
		dig_6:		TNG
		dig_7:		TOS
		dig_8:		https://freesound.org/people/MrFossy/sounds/590042/
		dig_9:		https://freesound.org/people/tim.kahn/sounds/130377/
		break_1:	https://freesound.org/people/BloodPixelHero/sounds/572938/
		break_2:	https://freesound.org/people/RICHERlandTV/sounds/216090/
		break_3:	https://freesound.org/people/Set214/sounds/844648/
		full_1:		https://freesound.org/people/Reitanna/sounds/264152/
		full_2:		https://freesound.org/people/chennes/sounds/376807/
		anime_wow:	Konami / FairyTail / ???
		konami_wow:	Konami.
		owen_wow:	Owen.
		haha_1:		Nelson.
		haha_2:		https://freesound.org/people/akapastels/sounds/697899/
		haha_3:		https://freesound.org/people/insanity54/sounds/325462/


		Ashita doesn't have any kind of volume control, so we actually have to control that with the sound file itself. Not great.
			An individual sounders structure will be passed to the play_sound function when we want to play it.
			The play_sound function will handle the full filenames, but they will resolve to: addon.path /sounders/[filename]_[low/med/high].wav
--]]
	sounders = T {
		dig_ready = T {
			enabled = T {true},
			sound_selected = T {7},
			sound_volume = 1, -- 1: Low, 2: Medium, 3: High.
			sound_count = 9,
			randomize = T {true},
			sound_list = T { -- label for displaying in the config, file for working out the acutal filename.
				[1] = T { label = 'Blip', filename = 'dig_8' },
				[2] = T { label = 'Blip-Blip 1', filename = 'dig_1' },
				[3] = T { label = 'Blip-Blip 2', filename = 'dig_2' },
				[4] = T { label = 'Blip-Blip 3', filename = 'dig_3' },
				[5] = T { label = 'Pop', filename = 'dig_4' },
				[6] = T { label = 'Sonar', filename = 'dig_9' },
				[7] = T { label = 'Dig-Dig-Diggy-Digger!', filename = 'dig_5' },
				[8] = T { label = "He's Dig, Jim!", filename = 'dig_7' },
				[9] = T { label = 'To Boldly Dig...', filename = 'dig_6' },
			},
		},
		-- Bucket Break sounder.
		bucket_break = T {
			enabled = T {true},
			sound_selected = T {1},
			sound_volume = 1; -- 1: Low, 2: Medium, 3: High.
			sound_count = 3,
			randomize = T {true},
			sound_list = T { -- label for displaying in the config, file for working out the acutal filename.
				[1] = T { label = 'Error 1', filename = 'break_1' },
				[2] = T { label = 'Error 2', filename = 'break_2' },
				[3] = T { label = 'Shatter', filename = 'break_3' },
			},
		},
		-- Bucket Full sounder.
		bucket_full = T {
			enabled = T {true},
			sound_selected = T {1},
			sound_volume = 1; -- 1: Low, 2: Medium, 3: High.
			sound_count = 3,
			randomize = T {true},
			sound_list = T { -- label for displaying in the config, file for working out the acutal filename.
				[1] = T { label = 'Ding 1', filename = 'full_1' },
				[2] = T { label = 'Ding 2', filename = 'full_2' },
				[3] = T { label = 'Double Ding', filename = 'full_3' },
			},
		},
		-- Haha sounder -- Specific Conditions!
		haha = T {
			enabled = T {true}, -- We'll actually update this from the bucket_break sounder when we go to play one of these.
			sound_selected = T {1}, -- We'll randomize this when we go to play it.
			sound_volume = 1; -- 1: Low, 2: Medium, 3: High. We'll actually update this from the bucket_break sounder when we go to play one of these.
			sound_count = 3, -- Should be how many sounders are in the list, since we'll use it to make a random number between 1 and this.
			randomize = T {true},
			sound_list = T { -- We only need the filename part since we're going to randomly select this.
			[1] = T { label = 'HaHa!', filename = 'haha_1' },
			[2] = T { label = 'HaHa!', filename = 'haha_2' },
			[3] = T { label = 'HaHa!', filename = 'haha_3' },
			},
		},
		-- Wow sounder -- Specific Conditions!
		wow	= T {
			enabled = T {true}, -- We'll actually update this from the bucket_full sounder when we go to play one of these.
			sound_selected = T {1}, -- We'll randomize this when we go to play it.
			sound_volume = 1; -- 1: Low, 2: Medium, 3: High. We'll actually update this from the bucket_full sounder when we go to play one of these.
			sound_count = 3, -- Should be how many sounders are in the list, since we'll use it to make a random number between 1 and this.
			randomize = T {true},
			sound_list = T { -- We only need the filename part since we're going to randomly select this.
			[1] = T { label = 'WoW!', filename = 'anime_wow' },
			[2] = T { label = 'WoW!', filename = 'konami_wow' },
			[3] = T { label = 'WoW!', filename = 'owen_wow' },
			},
		},
	}, -- END Sounders
	statistics = T { -- For recording things that happen.
		items = T {
			total = 0,
			gained = 0,
			lost = 0,
			highest = T {
				gained = 0,
				lost = 0,
				unique = 0,
				unique_gained = 0,
				unique_lost = 0,
			},
		}, -- END statistics.items
		buckets = T {
			total = 0,
			breaks = T {
				total = 0,
				first = 0,
				second = 0,
				third = 0,
				fourth = 0,
				incidents = 0, -- It counts as a break, and is automatically included in the fourth counter, but we still want to know how many we had.
			},
			upgrades = T {
				total = 0,
				first = 0,
				second = 0,
				third = 0,
			},
			turnins = T {
				total = 0,
				first = 0,
				second = 0,
				third = 0,
				fourth = 0,
				empty = T {
					total = 0,
					first = 0,
					second = 0,
					third = 0,
					fourth = 0,
				}
			},
		}, -- END statistics.buckets
		value = T {
			gained = 0,
			lost = 0,
			highest = T {
				gained = 0,
				lost = 0,
			},
		}, -- END statistics.value
		just_one_more = 0, -- Successful digs after the bucket is full.
		just_one_oops = 0, -- Unsuccessful digs after the bucket is full.
	}, -- END statistics
	item_list = data.item_list, -- Populate with our items data structure from constants.
	last_break = T { -- Probably fine to put into the non-settings-handled data, but means we maintain the tracking if the addon is reloaded while mid session and we're not resetting session on load.
		last_item_dug = nil, -- Set to the most recent item found when digging. Used to know what broke a bucket.
		item = nil, -- Set to the last item to break a bucket. Disregard if last_break_incident is true.
		incident = false, -- Set to false if there's a regular bucket break, set to true if it was from an 'incident'. Used to know when not to say the last_item_dug broke a bucket.
	},
	last_upgrade_weight = 0, -- Set this to the current bucket weight when we get a new bucket, or upgrade the bucket. (For knowing if the bucket was turned in without adding anything after the purchase/upgrade).
};

local clamit = T {
	settings = settings.load(default_settings),
	current_character_name = nil, -- Updated on loading.
	current_character_race_id = 1, -- Updated on loading. We'll use this to see if it's a male or female character (odd = male, even = female) for the swimming gear display.
	horizon_server = true, -- Would like to be have this update on load eventually...
	had_first_load = false;
	-- Images, actual data read on loading.
	gear_icons = T {}, -- [m/f]_[top/bottom]_[on/off] -> 'm_top_on' etc
	item_icons = T {}, -- log name as key
	gil_icon = nil,
	-- Message queue. It's a bad idea to print new messages while processing incoming text, so we'll put all messages in here, and go through them in the main loop.
	pending_message = false, -- Do we have any messages to print out from the text_in processing? Printed out in the main loop.
	pending_messages = T {}, -- Messages to print out from the text_in processing.
	-- Tracking stuff that doesn't need to be saved between runs.
	tracking = T {
		autosave_item_counter = 0, -- Item counter for if we're auto-saving after a certain number of digs.
		dig_timer = 0, -- Used to track time since digging. (This is where we put the calculated count[up/down], not the timestamp).
		last_action = 0, -- Used to track the timeout for showing the tracking / bucket window.
		current_area = 0, -- Updated on loading. Used to know if we changed area.
		last_area = 0, -- Used to know if we changed area - leaving bibiki / zoning screws the bucket.
		gil_per_hour = 0,
		show_override = false, -- Used to show bucket / stats while out of area with out of area disabled.
	},
};


--[[
	Custom / Useful Functions
--]]

local function add_message(message,only_verbose)
	-- If it's a verbose message, and verbose is off, we can just skip it.
	if (only_verbose and not clamit.settings.general.verbose[1]) then return end
	if (message ~= nil) then
		clamit.pending_message = true;
		table.insert(clamit.pending_messages,message);
	end
end


local function load_image_file(path)
    if (path ~= nil and ashita.fs.exists(path)) then
        local dx_texture_ptr = ffi.new('IDirect3DTexture8*[1]');
        if (ffi.C.D3DXCreateTextureFromFileA(d3d8dev, path, dx_texture_ptr) == ffi.C.S_OK) then
            local texture = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]));
            local result, desc = texture:GetLevelDesc(0);
            if result == 0 then
                tx         = {};
                tx.Texture = texture;
				tx.Pointer = tonumber(ffi.cast('uint32_t', texture));
                tx.Width   = desc.Width;
                tx.Height  = desc.Height;
                return tx;
            end
        end
    end
	return nil;
end

local function load_clamming_icons()
	-- Load up the icons for all the items. Filenames are based on the in-game item ids.
	for i = 1, data.item_count do
		local this_item = data.sorting.alpha_asc[i];
		local this_file = addon.path .. '/images/icons/' .. tostring(data.item_list[this_item].id) .. '.png'; -- We're using the data from the constants.lua so we're not using saved data, which would be problematic if we changed anything.
		clamit.item_icons[this_item] = load_image_file(this_file);
	end
	-- Load the gil icon
	clamit.gil_icon = load_image_file(addon.path .. '/images/icons/gil.png');
	-- Load the swimming gear icons
	clamit.gear_icons.m_top_off = load_image_file(addon.path .. '/images/icons/m_top_gs.png');
	clamit.gear_icons.m_top_on = load_image_file(addon.path .. '/images/icons/m_top.png');
	clamit.gear_icons.m_bottom_off = load_image_file(addon.path .. '/images/icons/m_bottom_gs.png');
	clamit.gear_icons.m_bottom_on = load_image_file(addon.path .. '/images/icons/m_bottom.png');
	clamit.gear_icons.f_top_off = load_image_file(addon.path .. '/images/icons/f_top_gs.png');
	clamit.gear_icons.f_top_on = load_image_file(addon.path .. '/images/icons/f_top.png');
	clamit.gear_icons.f_bottom_off = load_image_file(addon.path .. '/images/icons/f_bottom_gs.png');
	clamit.gear_icons.f_bottom_on = load_image_file(addon.path .. '/images/icons/f_bottom.png');
end

local function time_since(when)
	-- For the session timer display. We're expecting the basic ms timestamp from clamit.settings.session.start_time, so everything is 1000 times more than it would be for seconds, and we have to start with current time.
	local elapsed = (ashita.time.clock()['ms'] - when) / 1000;
    local days = math.floor(elapsed / 86400)
    local hours = math.floor((elapsed % 86400) / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local secs = math.floor(elapsed % 60)
	local output = '';
	if (days > 0) then
		output = tostring(days);
	end
	if (hours > 0 or days > 0) then
		if (days > 0) then output = output .. ':'; end
		if (hours < 10 and (days > 0)) then
			output = output .. '0' .. tostring(hours);
		else
			output = output .. tostring(hours);
		end
	end
	if (minutes > 0 or hours > 0 or days > 0) then
		if (days > 0 or hours > 0) then output = output .. ':'; end
		if (minutes < 10 and (days > 0 or hours > 0)) then
			output = output .. '0' .. tostring(minutes);
		else
			output = output .. tostring(minutes);
		end
	end
	if (secs > 0 or minutes > 0 or hours > 0 or days > 0) then
		if (days > 0 or hours > 0 or minutes > 0) then output = output .. ':'; end
		if (secs < 10 and (days > 0 or hours > 0 or minutes > 0)) then
			output = output .. '0' .. tostring(secs);
		else
			output = output .. tostring(secs);
		end
	end
	return output;
end

local function contents_value(contents)
	-- Calculate the value of a set of contents - bucket contents, session gains, etc...
	local totals = 0;
	if (contents ~= nil and contents ~= {}) then
		for k, v in pairs(contents) do
			if (v > 0 and v ~= nil and k ~= nil and k ~= '') then
				if (clamit.settings.item_list[k].use_ah[1] and clamit.settings.item_list[k].ah_value[1] > 0) then
					totals = totals + (clamit.settings.item_list[k].ah_value[1] * v);
				elseif (clamit.settings.general.bucket.vendor_value_low[1]) then
					totals = totals + (clamit.settings.item_list[k].vendor_low[1] * v);
				else
					totals = totals + (clamit.settings.item_list[k].vendor_high[1] * v);
				end
			end
		end
	end
	return totals;
end

local function check_bucket_ki() -- Why bother? Current Horizon ashita version doesn't work for this KI command, so it's in this function in case a work-around is found, and then it won't disrupt the rest of the code.
	return AshitaCore:GetMemoryManager():GetPlayer():HasKeyItem(511);
end

local function clear_bucket()
	-- Reset the bucket - probably doesn't need to be this way, but easier if the defaults change at some point...
	clamit.settings.bucket.active = default_settings.bucket.active;
	clamit.settings.bucket.broken = default_settings.bucket.broken;
	clamit.settings.bucket.zoned = default_settings.bucket.zoned;
	clamit.settings.bucket.items.total = default_settings.bucket.items.total;
	clamit.settings.bucket.items.unique = default_settings.bucket.items.unique;
	clamit.settings.bucket.weight = default_settings.bucket.weight;
	clamit.settings.bucket.capacity = default_settings.bucket.capacity;
	clamit.settings.bucket.contents = T {};
end

local function clear_session(check)
	-- Reset the session - probably doesn't need to be this way, but easier if the defaults change at some point...
	clamit.settings.session.start_time = default_settings.session.start_time;
	clamit.settings.session.items.total = default_settings.session.items.total;
	clamit.settings.session.items.gained = default_settings.session.items.gained;
	clamit.settings.session.items.lost = default_settings.session.items.lost;
	clamit.settings.session.items.unique = default_settings.session.items.unique;
	clamit.settings.session.buckets.total = default_settings.session.buckets.total;
	clamit.settings.session.buckets.breaks = default_settings.session.buckets.breaks;
	clamit.settings.session.buckets.upgrades = default_settings.session.buckets.upgrades;
	clamit.settings.session.buckets.turnins = default_settings.session.buckets.turnins;
	clamit.settings.session.gained = T {};
	clamit.settings.session.lost = T {};
end

local function reset_defaults()
	-- Backup display status...
	local temp_config_display = clamit.settings.display.config_window.visible[1];
	local temp_config_tab = clamit.settings.display.config_window.tab;
	-- Backup the statistics - LUA hates arrays/tables, so this is unwieldy...
	local temp_statistics = T {
		items = T {
			total = clamit.settings.statistics.items.total,
			gained = clamit.settings.statistics.items.gained,
			lost = clamit.settings.statistics.items.lost,
			highest = T {
				gained = clamit.settings.statistics.items.highest.gained,
				lost = clamit.settings.statistics.items.highest.lost,
				unique = clamit.settings.statistics.items.highest.unique,
				unique_gained = clamit.settings.statistics.items.highest.unique_gained,
				unique_lost = clamit.settings.statistics.items.highest.unique_lost,
			},
		},
		buckets = T {
			total = clamit.settings.statistics.buckets.total,
			breaks = T {
				total = clamit.settings.statistics.buckets.breaks.total,
				first = clamit.settings.statistics.buckets.breaks.first,
				second = clamit.settings.statistics.buckets.breaks.second,
				third = clamit.settings.statistics.buckets.breaks.third,
				fourth = clamit.settings.statistics.buckets.breaks.fourth,
				incidents = clamit.settings.statistics.buckets.breaks.incidents,
			},
			upgrades = T {
				total = clamit.settings.statistics.buckets.upgrades.total,
				first = clamit.settings.statistics.buckets.upgrades.first,
				second = clamit.settings.statistics.buckets.upgrades.second,
				third = clamit.settings.statistics.buckets.upgrades.third,
			},
			turnins = T {
				total = clamit.settings.statistics.buckets.turnins.total,
				first = clamit.settings.statistics.buckets.turnins.first,
				second = clamit.settings.statistics.buckets.turnins.second,
				third = clamit.settings.statistics.buckets.turnins.third,
				fourth = clamit.settings.statistics.buckets.turnins.fourth,
				empty = T {
					total = clamit.settings.statistics.buckets.turnins.empty.total,
					first = clamit.settings.statistics.buckets.turnins.empty.first,
					second = clamit.settings.statistics.buckets.turnins.empty.second,
					third = clamit.settings.statistics.buckets.turnins.empty.third,
					fourth = clamit.settings.statistics.buckets.turnins.empty.fourth,
				}
			},
		},
		value = T {
			gained = clamit.settings.statistics.value.gained,
			lost = clamit.settings.statistics.value.lost,
			highest = T {
				gained = clamit.settings.statistics.value.highest.gained,
				lost = clamit.settings.statistics.value.highest.lost,
			},
		},
		just_one_more = clamit.settings.statistics.just_one_more,
		just_one_oops = clamit.settings.statistics.just_one_oops,
	};
	-- Backup the session - LUA hates arrays/tables, so this is unwieldy...
	local temp_session = T {
		start_time = clamit.settings.session.start_time,
		items = T {
			total = clamit.settings.session.items.total,
			gained = clamit.settings.session.items.gained,
			lost = clamit.settings.session.items.lost,
			unique = clamit.settings.session.items.unique,
		},
		buckets = T {
			total = clamit.settings.session.buckets.total,
			breaks = clamit.settings.session.buckets.breaks,
			upgrades = clamit.settings.session.buckets.upgrades,
			turnins = clamit.settings.session.buckets.turnins,
		},
		gained = T {},
		lost = T {},
	};
	for k, v in pairs(clamit.settings.session.gained) do
		temp_session.gained[k] = v;
	end
	for k, v in pairs(clamit.settings.session.lost) do
		temp_session.lost[k] = v;
	end
	-- Backup the bucket - LUA hates arrays/tables, so this is unwieldy...
	local temp_bucket = T {
		active = clamit.settings.bucket.active,
		broken = clamit.settings.bucket.broken,
		zoned = clamit.settings.bucket.zoned,
		items = T {
			total = clamit.settings.bucket.items.total,
			unique = clamit.settings.bucket.items.unique,
		},
		weight = clamit.settings.bucket.weight,
		capacity = clamit.settings.bucket.capacity,
		contents = T {},
	};
	for k, v in pairs(clamit.settings.bucket.contents) do
		temp_bucket.contents[k] = v;
	end
	-- Backup Item Specific Statistics
	local temp_items = T {};
	for i = 1, data.item_count do
		local this_item = data.sorting.alpha_asc[i];
		temp_items[this_item] = T {
			seen = clamit.settings.item_list[this_item].lifetime.seen,
			seen_hq = clamit.settings.item_list[this_item].lifetime.seen_hq,
			gained = clamit.settings.item_list[this_item].lifetime.gained,
			one_bucket = clamit.settings.item_list[this_item].lifetime.one_bucket,
			one_bucket_gained = clamit.settings.item_list[this_item].lifetime.one_bucket_gained,
			last_straw = clamit.settings.item_list[this_item].lifetime.last_straw,
		};
	end
	-- Do the main reset
	settings.reset();
	-- Restore display status
	clamit.settings.display.config_window.visible[1] = temp_config_display;
	clamit.settings.display.tab = temp_config_tab;
	-- Restore Statistics
	clamit.settings.statistics.items.total = temp_statistics.items.total;
	clamit.settings.statistics.items.gained = temp_statistics.items.gained;
	clamit.settings.statistics.items.lost = temp_statistics.items.lost;
	clamit.settings.statistics.items.highest.gained = temp_statistics.items.highest.gained;
	clamit.settings.statistics.items.highest.lost = temp_statistics.items.highest.lost;
	clamit.settings.statistics.items.highest.unique = temp_statistics.items.highest.unique;
	clamit.settings.statistics.items.highest.unique_gained = temp_statistics.items.highest.unique_gained;
	clamit.settings.statistics.items.highest.unique_lost = temp_statistics.items.highest.unique_lost;
	clamit.settings.statistics.buckets.total = temp_statistics.buckets.total;
	clamit.settings.statistics.buckets.breaks.total = temp_statistics.buckets.breaks.total;
	clamit.settings.statistics.buckets.breaks.first = temp_statistics.buckets.breaks.first;
	clamit.settings.statistics.buckets.breaks.second = temp_statistics.buckets.breaks.second;
	clamit.settings.statistics.buckets.breaks.third = temp_statistics.buckets.breaks.third;
	clamit.settings.statistics.buckets.breaks.fourth = temp_statistics.buckets.breaks.fourth;
	clamit.settings.statistics.buckets.breaks.incidents = temp_statistics.buckets.breaks.incidents;
	clamit.settings.statistics.buckets.upgrades.total = temp_statistics.buckets.upgrades.total;
	clamit.settings.statistics.buckets.upgrades.first = temp_statistics.buckets.upgrades.first;
	clamit.settings.statistics.buckets.upgrades.second = temp_statistics.buckets.upgrades.second;
	clamit.settings.statistics.buckets.upgrades.third = temp_statistics.buckets.upgrades.third;
	clamit.settings.statistics.buckets.turnins.total = temp_statistics.buckets.turnins.total;
	clamit.settings.statistics.buckets.turnins.first = temp_statistics.buckets.turnins.first;
	clamit.settings.statistics.buckets.turnins.second = temp_statistics.buckets.turnins.second;
	clamit.settings.statistics.buckets.turnins.third = temp_statistics.buckets.turnins.third;
	clamit.settings.statistics.buckets.turnins.fourth = temp_statistics.buckets.turnins.fourth;
	clamit.settings.statistics.buckets.turnins.empty.total = temp_statistics.buckets.turnins.empty.total;
	clamit.settings.statistics.buckets.turnins.empty.first = temp_statistics.buckets.turnins.empty.first;
	clamit.settings.statistics.buckets.turnins.empty.second = temp_statistics.buckets.turnins.empty.second;
	clamit.settings.statistics.buckets.turnins.empty.third = temp_statistics.buckets.turnins.empty.third;
	clamit.settings.statistics.buckets.turnins.empty.fourth = temp_statistics.buckets.turnins.empty.fourth;
	clamit.settings.statistics.value.gained = temp_statistics.value.gained;
	clamit.settings.statistics.value.lost = temp_statistics.value.lost;
	clamit.settings.statistics.value.highest.gained = temp_statistics.value.highest.gained;
	clamit.settings.statistics.value.highest.lost = temp_statistics.value.highest.lost;
	clamit.settings.statistics.just_one_more = temp_statistics.just_one_more;
	clamit.settings.statistics.just_one_oops = temp_statistics.just_one_oops;
	-- Restore Session
	clamit.settings.session.start_time = temp_session.start_time;
	clamit.settings.session.items.total = temp_session.items.total;
	clamit.settings.session.items.gained = temp_session.items.gained;
	clamit.settings.session.items.lost = temp_session.items.lost;
	clamit.settings.session.items.unique = temp_session.items.unique;
	clamit.settings.session.buckets.total = temp_session.buckets.total;
	clamit.settings.session.buckets.breaks = temp_session.buckets.breaks;
	clamit.settings.session.buckets.upgrades = temp_session.buckets.upgrades;
	clamit.settings.session.buckets.turnins = temp_session.buckets.turnins;
	clamit.settings.session.gained = T {};
	clamit.settings.session.lost = T {};
	for k, v in pairs(temp_session.gained) do
		clamit.settings.session.gained[k] = v;
	end
	for k, v in pairs(temp_session.lost) do
		clamit.settings.session.lost[k] = v;
	end
	-- Restore Bucket
	clamit.settings.bucket.active = temp_bucket.active;
	clamit.settings.bucket.broken = temp_bucket.broken;
	clamit.settings.bucket.zoned = temp_bucket.zoned;
	clamit.settings.bucket.items.total = temp_bucket.items.total;
	clamit.settings.bucket.items.unique = temp_bucket.items.unique;
	clamit.settings.bucket.weight = temp_bucket.weight;
	clamit.settings.bucket.capacity = temp_bucket.capacity;
	contents = T {};
	for k, v in pairs(temp_bucket.contents) do
		clamit.settings.bucket.contents[k] = v;
	end
	-- Restore Item Specific Statistics
	for i = 1, data.item_count do
		local this_item = data.sorting.alpha_asc[i];
			clamit.settings.item_list[this_item].lifetime.seen = temp_items[this_item].seen;
			clamit.settings.item_list[this_item].lifetime.seen_hq = temp_items[this_item].seen_hq;
			clamit.settings.item_list[this_item].lifetime.gained = temp_items[this_item].gained;
			clamit.settings.item_list[this_item].lifetime.one_bucket = temp_items[this_item].one_bucket;
			clamit.settings.item_list[this_item].lifetime.one_bucket_gained = temp_items[this_item].one_bucket_gained;
			clamit.settings.item_list[this_item].lifetime.last_straw = temp_items[this_item].last_straw;
	end
	settings.save();
end

local function check_hq_legs()
	local hq_legs = false;
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
	if (inventory == nil) then return false; end -- Something clearly went wrong...
	local leg_equipped = inventory:GetEquippedItem(7);
	if (leg_equipped ~= nil) then -- Make sure there's actually something equipped...
		local leg_item = inventory:GetContainerItem((bit.band(leg_equipped.Index, 0xFF00) / 256), bit.band(leg_equipped.Index, 0x00FF));
		if (tostring(leg_item.Id):any('15415','15416','15417','15418','15419','15420','15421','15424')) then -- Check what's equipped against the list of items...
			hq_legs = true;
		end
	end
	return hq_legs;
end

local function check_hq_body()
	local hq_body = false;
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
	if (inventory == nil) then return false; end -- Something clearly went wrong...
	-- Get the currently equipped body and check it against the Id's for HQ swim top that 'reduces clamming incidents'.
    local body_equipped = inventory:GetEquippedItem(5);
	if (body_equipped ~= nil) then -- Make sure there's actually something equipped...
		local body_item = inventory:GetContainerItem((bit.band(body_equipped.Index, 0xFF00) / 256), bit.band(body_equipped.Index, 0x00FF));
		if (tostring(body_item.Id):any('14457','14458','14459','14460','14461','14462','14463','14472')) then -- Check what's equipped against the list of items...
			hq_body = true;
		end
	end
	return hq_body;
end

local function check_hq() -- Might be deprecated.
	return check_hq_body(), check_hq_legs();
end

local function play_sound(sounder_table)
--[[
	sounder_table should be the specific sounder to be played, eg. clamit.settings.sounders.dig_ready
		sounder_table = T {	
			enabled = T {true}, Should it actually play?
			sound_selected = T {n}, Index for the sound_list selection.
			sound_volume = 1; -- 1: Low, 2: Medium, 3: High.
			sound_list = T {
				[n] = T { label = 'Display Name', file = 'first part of file name' },
			},
		}
--]]
	if (sounder_table == nil or sounder_table == {}) then return; end -- Something went wrong, don't play any sound.
	if (not sounder_table.enabled[1]) then return; end -- Sounder is disabled, don't play any sound.
	local sound_selected = sounder_table.sound_selected[1];
	if (sounder_table.randomize[1]) then
		sound_selected = math.random(sounder_table.sound_count);
	end
	local sound_file = sounder_table.sound_list[sound_selected].filename;
	if (not sound_file) then return; end -- Something wrong, don't play any sound.
	if (sounder_table.sound_volume) then
		if (sounder_table.sound_volume == 1) then
			sound_file = sound_file .. '_low.wav';
		elseif (sounder_table.sound_volume == 2) then
			sound_file = sound_file .. '_med.wav';
		elseif (sounder_table.sound_volume == 3) then
			sound_file = sound_file .. '_high.wav';
		else -- It's not accurate... let's just assume 2/Medium...
			sound_file = sound_file .. '_med.wav';
		end
	else -- Something wrong, don't play any sound
		return;
	end
	local full_sound_file = addon.path .. 'sounders/' .. sound_file;
	if (not ashita.fs.exists(full_sound_file)) then return; end -- The file doesn't exists, so let's quit.
	ashita.misc.play_sound(full_sound_file);
	add_message("Playing sounder: " .. sounder_table.sound_list[sound_selected].label,true);
end

local function pad_to(str, num, start)
	-- Useful for making the display look tidier.
	if (string.len(str) < num) then
		local count = num - string.len(str);
		if (start) then
			for _ = 1, count do
				str = ' ' .. str;
			end
		else
			for _ = 1, count do
				str = str .. ' ';
			end
		end
	end
	return str;
end

----------------------------------------------------------------------------------------------------
-- Format numbers with commas
-- https://stackoverflow.com/questions/10989788/format-integer-in-lua
----------------------------------------------------------------------------------------------------
local function format_int(number)
	if (string.len(number) < 4) then return number end
	if (number ~= nil and number ~= '' and type(number) == 'number') then
		local _, _, minus, int, fraction =
			tostring(number):find('([-]?)(%d+)([.]?%d*)');

		-- we sometimes get a nil int from the above tostring, just return number in those cases
		if (int == nil) then return number end

		-- reverse the int-string and append a comma to all blocks of 3 digits
		int = int:reverse():gsub("(%d%d%d)", "%1,");

		-- reverse the int-string back remove an optional comma and put the
		-- optional minus and fractional part back
		return minus .. int:reverse():gsub("^,", "") .. fraction;
	else
		return 'NaN';
	end
end

--[[
* event: load %%LOAD%%
* desc : Event called when the addon is being loaded.
--]]
local function load_character()
	-- Things to do for character load - also things to do if the character *changes*
	clamit.current_character_name = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0) or nil;
	if (clamit.current_character_name ~= nil) then
		local player_entity = GetPlayerEntity();
		if (player_entity ~= nil) then
			clamit.current_character_race_id = player_entity.Race;
		end;
	end
	if (clamit.settings.general.clear_bucket[1]) then -- Clear the bucket if we need to...
		clear_bucket();
	end
	if (clamit.settings.general.clear_session[1]) then -- Clear the session if we need to...
		clear_session();
	end
	clamit.tracking.current_area = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
	clamit.tracking.last_area = 0;
	clamit.tracking.autosave_item_counter = 0;
	clamit.tracking.gil_per_hour = 0;
end
ashita.events.register('load', 'load_callback1', function ()
	load_clamming_icons(); -- Load icon images for use
	clamit.had_first_load = true;
	load_character();
end);

--[[
* event: unload %%UNLOAD%%
* desc : Event called when the addon is being unloaded.
--]]
ashita.events.register('unload', 'unload_callback1', function ()
    settings.save(); -- Save our data!
	clear_bucket();
	clear_session(false);
end);

--[[
* event: command %%COMMAND%%
* desc : Event called when the addon is processing a command.
	-- Included the 'print help' function to keep them together.
--]]
local function show_command_list(is_error)
	if (is_error) then -- If is_error is true, it means they tried a command we haven't setup, so print a message about that...
        print(chat.header(addon.name) .. chat.error('Unknown command!'));
    end
    print(chat.header(addon.name) .. chat.message('Available commands:'));
	print(chat.header(addon.name) .. chat.message("/clamit") .. ' or ' .. chat.message("/clamit config") .. " - " .. chat.color1(6, "Toggle the config window."));
	print(chat.header(addon.name) .. chat.message("/clamit help") .. " - " .. chat.color1(6, "Show this list."));
	print(chat.header(addon.name) .. chat.message("/clamit show") .. " - " .. chat.color1(6, "Show the bucket window (unless it's disabled out of area)."));
	print(chat.header(addon.name) .. chat.message("/clamit show override") .. " - " .. chat.color1(6, "Temporarily override the out of are setting."));
	print(chat.header(addon.name) .. chat.message("/clamit hide") .. " - " .. chat.color1(6, "Hide the bucket window (unless the config window is open)."));
	print(chat.header(addon.name) .. chat.message("/clamit clear") .. " - " .. chat.color1(6, "Clear the contents of the bucket and session."));
	print(chat.header(addon.name) .. chat.message("/clamit clear bucket") .. " - " .. chat.color1(6, "Clear the contents of the bucket."));
	print(chat.header(addon.name) .. chat.message("/clamit clear session") .. " - " .. chat.color1(6, "Clear the contents of the session."));
	print(chat.header(addon.name) .. chat.message("/clamit save") .. " - " .. chat.color1(6, "Save the current settings / data."));
	print(chat.header(addon.name) .. chat.message("/clamit load") .. " - " .. chat.color1(6, "Load the settings / data, losing any changes not saved."));
	print(chat.header(addon.name) .. chat.message("/clamit defaults") .. " - " .. chat.color1(6, "Reset the settings back to default. Does not clear statistics data."));
end
ashita.events.register('command', 'command_callback1', function (e)
    --[[ Valid Arguments
        e.mode       - (ReadOnly) The mode of the command.
        e.command    - (ReadOnly) The raw command string.
        e.injected   - (ReadOnly) Flag that states if the command was injected by Ashita or an addon/plugin.
        e.blocked    - (Writable) Flag that states if the command has been, or should be, blocked.
    --]]
	-- Parse the command arguments..
	local args = e.command:args();
	if (#args == 0 or not args[1]:any('/clamit')) then return; end -- The purpose of the :any() is actually to allow variations eg: :any('/clamit','/clam','/ci','/whatever') would mean this would process all of those commands. Seems like everyone copies the example without understanding it. Like I did. /shrug
	-- Block all related commands. (Stops something else using the same /command).
	e.blocked = true;


	-- /clamit or /clamit config
	if (#args == 1 or (#args >= 2 and args[2]:any('config'))) then
		clamit.settings.display.config_window.visible[1] = not clamit.settings.display.config_window.visible[1];
		return;
	end
	-- /clamit help
	if (#args >= 2 and args[2]:any('help')) then
		show_command_list(false); -- false because it's not an error;
		return;
	end
	-- /clamit show
	if (#args >= 2 and args[2]:any('show')) then
		local current_area = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0); -- Find the current area.
		if (#args >=3 and args[3]:any('override')) then
			clamit.tracking.show_override = true;
			clamit.tracking.last_action = ashita.time.clock()['ms'];
		else
			if (current_area ~= 4 and not clamit.settings.general.out_of_area[1]) then
				-- Put a message about not showing out of area.
				add_message("Cannot show while out of area with your settings. You can add 'override' to the command to temporarily override it.",false);
			else
				-- Update the last_action time so it'll make it visible.
				clamit.tracking.last_action = ashita.time.clock()['ms'];
			end
		end
		return;
	end
	-- /clamit hide
	if (#args >= 2 and args[2]:any('hide')) then
		-- Update the last_action time so it'll make it visible.
		clamit.tracking.last_action = 0;
		return;
	end
	-- /clamit clear [bucket/session]
	if (#args >= 2 and args[2]:any('clear')) then
		if (#args == 2) then
			-- Clear both session and bucket.
			clear_bucket();
			clear_session(true);
			add_message("Bucket and Session cleared.",false);
			settings.save();
		elseif (#args >=3 and args[3]:any('bucket')) then
			-- Clear the bucket.
			clear_bucket();
			add_message("Bucket cleared.",false);
			settings.save();
		elseif (#args >=3 and args[3]:any('session')) then
			-- Clear the session.
			clear_session(true);
			add_message("Session cleared.",false);
			settings.save();
		end
		return;
	end
	-- /clamit save
	if (#args >= 2 and args[2]:any('save')) then
		settings.save();
		add_message("Settings and Data saved.",false);
		return;
	end
	-- /clamit load
	if (#args >= 2 and args[2]:any('load')) then
		settings.load();
		add_message("Settings and Data loaded.",false);
		return;
	end
	-- /clamit defaults
	if (#args >= 2 and args[2]:any('save')) then
		reset_defaults();
		add_message("Settings reset to default, statistics data not cleared.",false);
		return;
	end
	-- /clamit verbose [on/off] -- "Hidden" option.
	if (#args >= 2 and args[2]:any('verbose')) then
		if (#args == 2) then -- No sub specified, toggle.
			clamit.settings.general.verbose[1] = not clamit.settings.general.verbose[1];
		elseif (#args >=3 and args[3]:any('on')) then
			clamit.settings.general.verbose[1] = true;
		elseif (#args >=3 and args[3]:any('off')) then
			clamit.settings.general.verbose[1] = false;
		end
		return;
	end
	-- Since we got to here, if wasn't something we've set, so show the help...
	show_command_list(true);
end);

--[[
* event: text_in %%TEXT%% %%PROCESS%%
* desc : Event called when the addon is processing incoming text.
--]]
ashita.events.register('text_in', 'text_in_callback1', function (e)
    --[[ Valid Arguments
        e.mode               - (ReadOnly) The message mode.
        e.indent             - (ReadOnly) Flag that determines if the message is indented.
        e.message            - (ReadOnly) The raw message string.
        e.mode_modified      - (Writable) The modified mode.
        e.indent_modified    - (Writable) The modified indent flag.
        e.message_modified   - (Writable) The modified message.
        e.injected           - (ReadOnly) Flag that states if the text was injected by Ashita or an addon/plugin.
        e.blocked            - (Writable) Flag that states if the text has been, or should be, blocked.
    --]] -- Don't print directly in this function, use add_message() instead. (It could bork things).

	--	Check if we actually need to do anything first:
	if (e.injected) then return; end -- We don't need to process stuff from other addons here, so skip it.
	local this_mode = bit.band(e.mode,  0x000000FF); -- If we don't do this, we get a bunch of extra bits we don't need, which make it harder to figure out wth we've just been given.
	if (this_mode ~= 142 and this_mode ~= 150 and this_mode ~=151) then return; end -- Everything we need to process should be 142, 150 or 151, so if it's not, skip it. Seriously, this stops idiots from borking it up by saying the text lines themselves, AND NOBODY ELSE SEEMS TO CHECK THIS! -.-
	local current_area = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0); -- Find the current area. We could probably use clamit.current_area, but better to be sure.
	if (current_area ~= 4) then	return;	end -- There's no clamming outside of bibiki bay, so if we're not there, we shouldn't bother processing anything at all.

	-- Since we got to here, we do need to process it, so here we go!
	local start_time = ashita.time.clock()['ms'];
	local save_settings = false;
	local sound_override = false; -- Used for the 'I dug again after the bucket was full' easter-egg, so that we don't play the normal break or full sound later.
	local this_message = e.message;
	this_message = string.lower(this_message); -- Make it all lowercase, easier to match text, and we're not needing to pull names for display - we've got those stored in the item data already.
	this_message = string.strip_colors(this_message); -- Take out the color coding, again makes it easier to match text.
	clamit.last_message = this_message; -- For debugging.

	-- Check a couple of things, and a couple variable we might use in more than one place.
	local bucket_KI = check_bucket_ki(); -- Does the player have the clamming kit in their key items?
	local has_hq_body, has_hq_legs = check_hq(); -- Is the player wearing the HQ clamming gear?
	local bucket_1 = clamit.settings.general.bucket.capacity[1];
	local bucket_2 = clamit.settings.general.bucket.capacity[1] * 2;
	local bucket_3 = clamit.settings.general.bucket.capacity[1] * 3;
	local bucket_4 = clamit.settings.general.bucket.capacity[1] * 4;

	-- Process the message to see what we're dealing with.
	local obtained_item_count, obtained_item =	string.match(this_message, data.text_searches.item_obtained);			-- Not doing anything with this yet, but could be used to verify gained items.
	local clamming_new_bucket =					string.match(this_message, data.text_searches.clamming_new_bucket);		-- Did we just get a new bucket?
	local clamming_dig_item =					string.match(this_message, data.text_searches.clamming_dig_item);		-- Did we just dig an item? !! Part of the same entry as the break message if it goes overweight.
	local clamming_bucket_upgrade =				string.match(this_message, data.text_searches.clamming_bucket_upgrade);	-- Did we just upgrade the bucket?
	local clamming_weight_check =				string.match(this_message, data.text_searches.clamming_weight_check);	-- Did we just talk to the NPC and have her tell us how much weight is in the bucket?
	local clamming_empty_bucket =				string.match(this_message, data.text_searches.clamming_empty_bucket);	-- Did we just talk to the NPC and have her tell us how much weight is in the bucket, but with an empty bucket?
	local clamming_bucket_turnin =				string.match(this_message, data.text_searches.clamming_bucket_turnin);	-- Did we just turn in the bucket? !! Same message even if it's a broken bucket.
	local clamming_overweight =					string.match(this_message, data.text_searches.clamming_overweight);		-- Did the bucket just break from being overweight? !! Part of the same entry as the dig item message.
	local clamming_incident =					string.match(this_message, data.text_searches.clamming_incident);		-- Did we just have an 'incident' with the top level bucket?
	local clamming_no_bucket =					string.match(this_message, data.text_searches.clamming_no_bucket);		-- Did we talk to the NPC without a bucket?
	local clamming_toh_zonikki =				string.match(this_message, data.text_searches.clamming_toh_zonikki);	-- Did we get this message from the bucket NPC? Just timer refresh...
	local clamming_dig_point_1 =				string.match(this_message, data.text_searches.clamming_dig_point_1);	-- Did we hit the Clamming Point? Used to refresh the display timer.
	local clamming_dig_point_2 =				string.match(this_message, data.text_searches.clamming_dig_point_2);	-- Did we hit the Clamming Point? Used to refresh the display timer.
	-- Some data integrity stuff, because LUA doesn't dynamically deal with number/text mismatches, and everything we just pulled in is text, even if it looks like a number. At least the default nil check works. (ie 'if (something) then' works (mostly) regardless of data type).
	if (obtained_item_count) then obtained_item_count = tonumber(obtained_item_count); end
	if (clamming_bucket_upgrade) then clamming_bucket_upgrade = tonumber(clamming_bucket_upgrade); end
	if (clamming_weight_check) then clamming_weight_check = tonumber(clamming_weight_check); end -- Will never give us a false negative, since we get a different message for an empty bucket.
	if (clamming_no_bucket) then clamming_no_bucket = tonumber(clamming_no_bucket); end

	-- Quick check of if we need to update the bucket status. Basically just error checking.
	if ((bucket_KI or clamming_empty_bucket) and not clamit.settings.bucket.active) then
		clamit.settings.bucket.active = true;
		add_message("Bucket set to active.",true);
	end

	-- Was it a dig action that would need us to start the dig timer?
	if (clamming_dig_item or clamming_overweight or clamming_incident) then
		if (clamit.tracking.dig_timer ~= 0) then end -- If it's not 0 when we're at this point, there's probably something wrong. Not really anything to do about it though...
		clamit.tracking.dig_timer = start_time;
	end

	-- Was it any kind of action that would need us to refresh the timout for the display?
	if (clamming_new_bucket or clamming_dig_item or clamming_bucket_upgrade or clamming_weight_check or clamming_empty_bucket or clamming_bucket_turnin or clamming_overweight or clamming_incident or clamming_no_bucket or clamming_dig_point_1 or clamming_dig_point_2 or clamming_toh_zonikki) then
		clamit.tracking.last_action = start_time;
	end

	-- Was it any kind of action that means we should start a session if it's not already started?
	if (clamming_new_bucket or clamming_dig_item or clamming_bucket_upgrade or clamming_bucket_turnin or clamming_overweight or clamming_incident) then
		if (clamit.settings.session.start_time == 0) then
			clamit.settings.session.start_time = start_time;
		end
	end

	-- No Bucket %%NOBUCKET%%
	if (clamming_no_bucket) then
		-- This comes up if we talk to Toh Zonikki without a bucket.
		if (clamit.settings.bucket.active or clamit.settings.bucket.broken) then
			-- Our tracking data is wrong, so reset the bucket.
			clear_bucket();
			add_message("Ghost bucket removed.",true);
		end
	end

	-- New Bucket %%NEWBUCKET%%
	if (clamming_new_bucket) then
		-- Clear the current bucket, and set this new one active
		clear_bucket();
		clamit.settings.bucket.active = true;
		clamit.settings.bucket.capacity = clamit.settings.general.bucket.capacity[1];
		add_message("New bucket purchased.",true);
		-- Add to the nucket statistics
		clamit.settings.statistics.buckets.total = clamit.settings.statistics.buckets.total + 1;
		-- Add to the session details
		clamit.settings.session.buckets.total = clamit.settings.session.buckets.total + 1;
		-- Reset tracking for handing in an empty bucket.
		clamit.settings.last_upgrade_weight = 0;
		-- Check if we should save settings...
		if (clamit.settings.general.autosave.bucket[1]) then 
			settings.save();
		end
	end

	-- Bucket Upgrade %%UPGRADEBUCKET%%
	if (clamming_bucket_upgrade) then
		if (clamming_bucket_upgrade ~= (clamit.settings.bucket.capacity + clamit.settings.general.bucket.capacity[1])) then
			-- Somehow the tracked capacity doesn't match what it should be for this upgrade, therefore our tracking data is probably wrong...
			add_message("Bucket upgraded doesn't match tracking, contents may be inaccurate.",false);
		end
		-- Even if there's a n issue, we still do the update.
		clamit.settings.bucket.capacity = clamming_bucket_upgrade;
		add_message("Bucket upgraded to: " .. clamming_bucket_upgrade .. ".",true);
		-- Update the stats.
		clamit.settings.statistics.buckets.upgrades.total = clamit.settings.statistics.buckets.upgrades.total + 1;
		if (clamming_bucket_upgrade == bucket_2) then
			clamit.settings.statistics.buckets.upgrades.first = clamit.settings.statistics.buckets.upgrades.first + 1;
		elseif (clamming_bucket_upgrade == bucket_3) then
			clamit.settings.statistics.buckets.upgrades.second = clamit.settings.statistics.buckets.upgrades.second + 1;
		elseif (clamming_bucket_upgrade == bucket_4) then
			clamit.settings.statistics.buckets.upgrades.third = clamit.settings.statistics.buckets.upgrades.third + 1;
		end
		-- Update the session - we don't use this yet, but we might...
		clamit.settings.session.buckets.upgrades = clamit.settings.session.buckets.upgrades + 1;
		-- Update tracking for handing in an bucket without adding anything after upgrading it.
		clamit.settings.last_upgrade_weight = clamit.settings.bucket.weight;
		-- Update the zoned status - you can continue a zoned bucket, you just don't get the original items.
		if (clamit.settings.bucket.zoned) then
			clamit.settings.bucket.zoned = false;
			add_message("Continued a zoned bucket, clearing zoned status.",true);
		end
	end

	-- Weight Check %%WEIGHTCHECK%%
	if (clamming_weight_check or clamming_empty_bucket) then
		if (clamming_empty_bucket) then
			clamming_weight_check = 0; -- If it's the empty bucket message we can just set this to 0 and have it work, since we're already within the right loop and nothing else below this uses the clamming_weight_check value.
		end
		if (clamming_weight_check ~= clamit.settings.bucket.weight or clamit.settings.bucket.capacity == 0 or clamming_weight_check > clamit.settings.bucket.capacity) then
			-- The bucket weight we have is wrong, update the weight.
			clamit.settings.bucket.weight = clamming_weight_check;
			add_message("Weight mis-match, updating the bucket.",false);
			-- The bucket capacity might be wrong too, so let's do some checking...
			if (clamming_weight_check > 0) then
				local predicted_capacity = 0;
				local possible_upgrade = false;
				if (clamming_weight_check > bucket_4) then
					-- Something is wrong if it got to here.
					predicted_capacity = bucket_4;
				elseif (clamming_weight_check <= bucket_4 and clamming_weight_check > bucket_3) then
					predicted_capacity = bucket_4;
				elseif (clamming_weight_check <= bucket_3 and clamming_weight_check > bucket_2) then
					predicted_capacity = bucket_3;
				elseif (clamming_weight_check <= bucket_2 and clamming_weight_check > bucket_1) then
					predicted_capacity = bucket_2;
				else
					predicted_capacity = bucket_1;
				end
				if ((predicted_capacity - clamming_weight_check) <= clamit.settings.weights.full[1]) then
					possible_upgrade = true;
				end
				if (possible_upgrade) then
					if (clamit.settings.bucket.capacity ~= predicted_capacity and clamit.settings.bucket.capacity ~= (predicted_capacity + bucket_1)) then
						-- Only update the capacity it's not the predicted capacity or the next one up from the prediction.
						clamit.settings.bucket.capacity = predicted_capacity;
					end
					-- Regardless of anything, we can't be 100% certain if we've got the right capacity, and we should only get to here if something went wrong (a crash, etc) so send a message about it.
					add_message("Bucket capacity uncertain, may be incorrect.",false);
				else
					-- The weight is not right for allowing an upgrade, so set it to the predicted capacity.
					clamit.settings.bucket.capacity = predicted_capacity;
				end
			else
				-- Weight is 0, so we can just set it to the base capacity.
				clamit.settings.bucket.weight = 0;
				clamit.settings.bucket.capacity = bucket_1;
			end
		end
		if (not clamit.settings.bucket.active or clamit.settings.bucket.broken) then
			-- Other info is guaranteed to be incorrect, so lets do a (limited) bucket reset.
			clamit.settings.bucket.active = true;
			clamit.settings.bucket.broken = false;
			clamit.settings.bucket.zoned = false;
			add_message("Bucket contents and stats may be incorrect.",false);
		end
		-- Update the zoned status - you can continue a zoned bucket, you just don't get the original items.
		if (clamit.settings.bucket.zoned) then
			clamit.settings.bucket.zoned = false;
			add_message("Continued a zoned bucket, clearing zoned status.",true);
		end
	end

	-- Bucket Turn-in %%BUCKETTURNIN%% %%LOGGING%% Some logging code might go in this section somewhere, too...
	if (clamming_bucket_turnin) then
		if (not clamit.settings.bucket.broken) then
			-- If it wasn't a broken bucket, we need to do some processing before clearing it.
			-- Bucket Value calculations.
			local this_bucket_value = contents_value(clamit.settings.bucket.contents);
			clamit.settings.statistics.value.gained = clamit.settings.statistics.value.gained + this_bucket_value;
			if (this_bucket_value > clamit.settings.statistics.value.highest.gained) then
				clamit.settings.statistics.value.highest.gained = this_bucket_value;
				add_message("New highest bucket value: " .. format_int(this_bucket_value) .. "g.",true);
			end
			-- Item Count calculations.
			clamit.settings.statistics.items.gained = clamit.settings.statistics.items.gained + clamit.settings.bucket.items.total;
			clamit.settings.session.items.gained = clamit.settings.session.items.gained + clamit.settings.bucket.items.total;
			if (clamit.settings.bucket.items.total > clamit.settings.statistics.items.highest.gained) then
				clamit.settings.statistics.items.highest.gained = clamit.settings.bucket.items.total;
				add_message("New highest number of items gained from a bucket: " .. clamit.settings.bucket.items.total,true);
			end
			if (clamit.settings.bucket.items.unique > clamit.settings.statistics.items.highest.unique_gained) then
				clamit.settings.statistics.items.highest.unique_gained = clamit.settings.bucket.items.unique;
				add_message("New highest number of unique items gained from a bucket: " .. clamit.settings.bucket.items.total,true);
			end
			-- Run through the contents for those calculations.
			for k, v in pairs(clamit.settings.bucket.contents) do
				if (k ~= nil and k ~= "" and v ~= nil and v > 0) then
					-- Do the statistics part.
					clamit.settings.item_list[k].lifetime.gained = clamit.settings.item_list[k].lifetime.gained + v;
					if (v > clamit.settings.item_list[k].lifetime.one_bucket_gained) then
						clamit.settings.item_list[k].lifetime.one_bucket_gained = v;
						add_message("New highest amount of " .. clamit.settings.item_list[k].name .. " gained in one bucket: " .. v .. ".",true);
					end
					-- Add them to the session list.
					if (clamit.settings.session.gained[k] ~= nil) then
						clamit.settings.session.gained[k] = clamit.settings.session.gained[k] + v;
					else
						clamit.settings.session.gained[k] = v;
						clamit.settings.session.items.unique = clamit.settings.session.items.unique + 1;
					end
				end
			end
			-- Turnins statistics
			clamit.settings.statistics.buckets.turnins.total = clamit.settings.statistics.buckets.turnins.total + 1;
			if (clamit.settings.bucket.capacity == bucket_1) then
				clamit.settings.statistics.buckets.turnins.first = clamit.settings.statistics.buckets.turnins.first + 1;
			elseif (clamit.settings.bucket.capacity == bucket_2) then
				clamit.settings.statistics.buckets.turnins.second = clamit.settings.statistics.buckets.turnins.second + 1;
			elseif (clamit.settings.bucket.capacity == bucket_3) then
				clamit.settings.statistics.buckets.turnins.third = clamit.settings.statistics.buckets.turnins.third + 1;
			elseif (clamit.settings.bucket.capacity == bucket_4) then
				clamit.settings.statistics.buckets.turnins.fourth = clamit.settings.statistics.buckets.turnins.fourth + 1;
			end
			-- Check if the bucket was handed in empty.
			if (clamit.settings.last_upgrade_weight == clamit.settings.bucket.weight or clamit.settings.bucket.weight == 0) then -- Don't need to check broken status since we're in the not broken loop.
				add_message("Bucket turned in withoug adding anything new.",true);
				clamit.settings.statistics.buckets.turnins.empty.total = clamit.settings.statistics.buckets.turnins.empty.total + 1;
				if (clamit.settings.bucket.capacity == bucket_1) then
					clamit.settings.statistics.buckets.turnins.empty.first = clamit.settings.statistics.buckets.turnins.empty.first + 1;
				elseif (clamit.settings.bucket.capacity == bucket_2) then
					clamit.settings.statistics.buckets.turnins.empty.second = clamit.settings.statistics.buckets.turnins.empty.second + 1;
				elseif (clamit.settings.bucket.capacity == bucket_3) then
					clamit.settings.statistics.buckets.turnins.empty.third = clamit.settings.statistics.buckets.turnins.empty.third + 1;
				elseif (clamit.settings.bucket.capacity == bucket_4) then
					clamit.settings.statistics.buckets.turnins.empty.fourth = clamit.settings.statistics.buckets.turnins.empty.fourth + 1;
				end
			end
		end
		clear_bucket();
		if (clamit.settings.general.autosave.turnin[1]) then
			save_settings = true;
		end
	end

	-- Item Dug %%ITEMDUG%% %%LOGGING%% Some logging code might go in this section somewhere..
	if (clamming_dig_item) then
		-- The text for an overweight bucket is in the same message as this one, so this part of the processing has to happen before the broken bucket processing or things might go screwy...
		if (clamit.settings.item_list[clamming_dig_item] ~= nil and clamit.settings.item_list[clamming_dig_item] ~= {}) then
			local previous_weight_diff = clamit.settings.bucket.capacity - clamit.settings.bucket.weight; -- Save this before we update the weight.
			-- Add the item to the bucket.
			clamit.settings.bucket.items.total = clamit.settings.bucket.items.total + 1;
			if (clamit.settings.bucket.contents[clamming_dig_item] ~= nil) then
				clamit.settings.bucket.contents[clamming_dig_item] = clamit.settings.bucket.contents[clamming_dig_item] + 1;
			else
				clamit.settings.bucket.contents[clamming_dig_item] = 1;
				clamit.settings.bucket.items.unique = clamit.settings.bucket.items.unique + 1;
				if (clamit.settings.bucket.items.unique > clamit.settings.statistics.items.highest.unique) then
					clamit.settings.statistics.items.highest.unique = clamit.settings.bucket.items.unique;
					add_message("New highest number of unique items seen in a bucket: " .. clamit.settings.bucket.items.unique .. ".",true);
				end
			end
			clamit.settings.bucket.weight = clamit.settings.bucket.weight + clamit.settings.item_list[clamming_dig_item].weight[1];
			-- More stats.
			clamit.settings.statistics.items.total = clamit.settings.statistics.items.total + 1;
			clamit.settings.item_list[clamming_dig_item].lifetime.seen = clamit.settings.item_list[clamming_dig_item].lifetime.seen + 1;
			if (has_hq_legs) then
				clamit.settings.item_list[clamming_dig_item].lifetime.seen_hq = clamit.settings.item_list[clamming_dig_item].lifetime.seen_hq + 1;
			end
			if (clamit.settings.bucket.contents[clamming_dig_item] > clamit.settings.item_list[clamming_dig_item].lifetime.one_bucket) then
				clamit.settings.item_list[clamming_dig_item].lifetime.one_bucket = clamit.settings.bucket.contents[clamming_dig_item];
				add_message("New highest number of " .. clamit.settings.item_list[clamming_dig_item].name .. " seen in a single bucket: " .. clamit.settings.bucket.contents[clamming_dig_item] .. ".",true);
			end
			-- Add it to the session counter.
			clamit.settings.session.items.total = clamit.settings.session.items.total + 1;
			-- Weight checking
			local weight_diff = clamit.settings.bucket.capacity - clamit.settings.bucket.weight;
			-- First check for the easter egg.
			if (previous_weight_diff <= clamit.settings.weights.full[1]) then
				-- The bucket was full before this dig... I have totally never done this myself...
				if (weight_diff < 0) then
					-- The bucket broke...
					clamit.settings.statistics.just_one_oops = clamit.settings.statistics.just_one_oops + 1;
					-- Prep the sounder, and bring in the settinngs from the bucket break sounder
					if (clamit.settings.general.easter_eggs[1]) then
						sound_override = true; -- Set this so it doesn't play the regular full or break sounders.
						clamit.settings.sounders.haha.enabled[1] = clamit.settings.sounders.bucket_break.enabled[1];
						clamit.settings.sounders.haha.sound_volume = clamit.settings.sounders.bucket_break.sound_volume;
						play_sound(clamit.settings.sounders.haha);
					end
					add_message("You dug when the bucket was already full, and now it's broken.",true);
				else
					-- The bucket.. didn't break!
					clamit.settings.statistics.just_one_more = clamit.settings.statistics.just_one_more + 1;
					-- Prep the sounder, and bring in the settinngs from the bucket full sounder
					if (clamit.settings.general.easter_eggs[1]) then
						sound_override = true; -- Set this so it doesn't play the regular full or break sounders.
						clamit.settings.sounders.wow.enabled[1] = clamit.settings.sounders.bucket_full.enabled[1];
						clamit.settings.sounders.wow.sound_volume = clamit.settings.sounders.bucket_full.sound_volume;
						play_sound(clamit.settings.sounders.wow);
					end
					add_message("You dug when the bucket was already full, and now it's broken.",true);
				end
			else -- It wasn't full before thie dig, so we're clear to do the bucket full sounder if necessary.
				-- Check if it was Oxblood.
				if (clamit.settings.item_list[clamming_dig_item].id == 1311 and clamit.settings.general.easter_eggs[1]) then
						-- In theory we don't need to check for a break before doing this, since you'd have to get it when the bucket counts as full to break it...
						add_message("You found an " .. clamit.settings.item_list[clamming_dig_item].name .. ":!",true);
						clamit.settings.sounders.wow.enabled[1] = clamit.settings.sounders.bucket_full.enabled[1];
						clamit.settings.sounders.wow.sound_volume = clamit.settings.sounders.bucket_full.sound_volume;
						play_sound(clamit.settings.sounders.wow);
				else -- Wasn't Oxblood (and easter eggs aren't disabled, so carry on!
					if (weight_diff <= clamit.settings.weights.full[1] and weight_diff >= 0) then
						play_sound(clamit.settings.sounders.bucket_full);
					end
				end
			end
			-- Now do the rest of the weight checking.
		else
			-- Somehow we got an unexpected item. Nothing to do...
			add_message("Unknown item: " .. clamming_dig_item .. "!",false);
		end
		-- Update the last item - even if it's unknown, we'll still set it.
		clamit.settings.last_break.last_item_dug = clamming_dig_item;
		-- Update the zoned status - you can continue a zoned bucket, you just don't get the original items.
		if (clamit.settings.bucket.zoned) then
			clamit.settings.bucket.zoned = false;
			add_message("Continued a zoned bucket, clearing zoned status.",true);
		end
		-- Check if we should autosave by item counter
		if (clamit.settings.general.autosave.item[1]) then
			clamit.tracking.autosave_item_counter = clamit.tracking.autosave_item_counter + 1;
			if (clamit.tracking.autosave_item_counter >= clamit.settings.general.autosave.item_count[1]) then
				clamit.tracking.autosave_item_counter = 0;
				settings.save();
			end
		end
	end

	-- Bucket Break - %%LOGGING%% Some logging code might go in this section somewhere..
	if (clamming_overweight or clamming_incident) then
		-- Update bucket break stats
		clamit.settings.statistics.buckets.breaks.total = clamit.settings.statistics.buckets.breaks.total + 1;
		if (clamit.settings.bucket.capacity == bucket_1) then
			clamit.settings.statistics.buckets.breaks.first = clamit.settings.statistics.buckets.breaks.first + 1;
		elseif (clamit.settings.bucket.capacity == bucket_2) then
			clamit.settings.statistics.buckets.breaks.second = clamit.settings.statistics.buckets.breaks.second + 1;
		elseif (clamit.settings.bucket.capacity == bucket_3) then
			clamit.settings.statistics.buckets.breaks.third = clamit.settings.statistics.buckets.breaks.third + 1;
		elseif (clamit.settings.bucket.capacity == bucket_3) then
			clamit.settings.statistics.buckets.breaks.fourth = clamit.settings.statistics.buckets.breaks.fourth + 1;
		end
		-- Update the last break tracking...
		if (clamming_incident) then
			clamit.settings.last_break.incident = true;
			clamit.settings.last_break.item = nil;
			clamit.settings.statistics.buckets.breaks.incidents = clamit.settings.statistics.buckets.breaks.incidents + 1;
		else
			clamit.settings.last_break.incident = false;
			if (clamit.settings.last_break.last_item_dug ~= nil and clamit.settings.last_break.last_item_dug ~='') then -- In theory, because this is a break from digging something up, it'll have recorded the item... We could probably just use clamming_dig_item directly too, but...
				clamit.settings.last_break.item = clamit.settings.last_break.last_item_dug;
				clamit.settings.item_list[clamit.settings.last_break.last_item_dug].lifetime.last_straw = clamit.settings.item_list[clamit.settings.last_break.last_item_dug].lifetime.last_straw + 1;
			end
		end
		-- Update losses stats
		local this_bucket_value = contents_value(clamit.settings.bucket.contents);
		clamit.settings.statistics.value.lost = clamit.settings.statistics.value.lost + this_bucket_value;
		if (this_bucket_value > clamit.settings.statistics.value.highest.lost) then
			clamit.settings.statistics.value.highest.lost = this_bucket_value;
			add_message("New highest value lost in a single bucket: " ..  format_int(this_bucket_value) .. "g.",true);
		end
		clamit.settings.statistics.items.lost = clamit.settings.statistics.items.lost + clamit.settings.bucket.items.total;
		if (clamit.settings.bucket.items.total > clamit.settings.statistics.items.highest.lost) then
			clamit.settings.statistics.items.highest.lost = clamit.settings.bucket.items.total;
			add_message("New highest number of items lost in a single bucket: " ..  clamit.settings.bucket.items.total .. ".",true);
		end
		if (clamit.settings.bucket.items.unique > clamit.settings.statistics.items.highest.unique_lost) then
			clamit.settings.statistics.items.highest.unique_lost = clamit.settings.bucket.items.unique;
		end
		-- Add the contents to the session's lost list.
		clamit.settings.session.buckets.breaks = clamit.settings.session.buckets.breaks + 1;
		for k, v in pairs(clamit.settings.bucket.contents) do
			if (clamit.settings.bucket.contents[k] ~= nil) then
				if (clamit.settings.session.lost[k] ~= nil) then
					clamit.settings.session.lost[k] = clamit.settings.session.lost[k] + v;
				else
					clamit.settings.session.lost[k] = v;
				end
				clamit.settings.session.items.lost = clamit.settings.session.items.lost + v;
			end
		end
		-- Clear the bucket contents and mark it as broken.
		clamit.settings.bucket.broken = true;
		clamit.settings.bucket.items.total = 0;
		clamit.settings.bucket.items.unique = 0;
		clamit.settings.bucket.weight = 0;
		clamit.settings.bucket.capacity = 0;
		clamit.settings.bucket.contents = T {};
		--Play the sounder if we need to
		if (not sound_override) then
			play_sound(clamit.settings.sounders.bucket_break);
		end
		-- Check if we need to auto save.
		if (clamit.settings.general.autosave.broken[1]) then
			save_settings = true;
		end
	end

	-- Last bit for the processing.
	if (save_settings) then settings.save(); end
end);

--[[
	Render functions for showing the various windows.
--]]
--[[ %%RENDER CONFIG%% --]]
local function render_config_general()
	if (imgui.BeginTable("##ConfigBodyGeneral", 1, bit.bor(ImGuiTableFlags_None))) then
		imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthStretch);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("General");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##GCOutOfArea",clamit.settings.general.out_of_area)
		imgui.SameLine();
		imgui.Text("Show out of area.");
		imgui.SameLine();
		imgui.ShowHelp("Allow the Bucket tracking window to show outside of Bibiki Bay, even when the config window is closed.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##GCSessionStats",clamit.settings.general.session_stats)
		imgui.SameLine();
		imgui.Text("Show Session item / bucket counts.");
		imgui.SameLine();
		imgui.ShowHelp("Show the item & bucket tallies in the Session section on the bucket window.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##GCClearBucket",clamit.settings.general.clear_bucket)
		imgui.SameLine();
		imgui.Text("Clear the bucket on load.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##GCClearSession",clamit.settings.general.clear_session)
		imgui.SameLine();
		imgui.Text("Clear the session on load.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Auto Save");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##ASTurnin",clamit.settings.general.autosave.turnin);
		imgui.SameLine();
		imgui.Text("Save on bucket turn-in.");
		--		
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##ASNewBucket",clamit.settings.general.autosave.bucket);
		imgui.SameLine();
		imgui.Text("Save when purchasing a bucket.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##ASBreak",clamit.settings.general.autosave.broken);
		imgui.SameLine();
		imgui.Text("Save when a bucket breaks.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SetNextItemWidth(150.0)
		imgui.InputInt("##ASItemCount",clamit.settings.general.autosave.item_count);
		if (not clamit.settings.general.autosave.item_count[1]) then
			clamit.settings.general.autosave.item_count[1] = 10;
		elseif (clamit.settings.general.autosave.item_count[1] > 100) then
			clamit.settings.general.autosave.item_count[1] = 100;
		elseif (clamit.settings.general.autosave.item_count[1] < 1) then
			clamit.settings.general.autosave.item_count[1] = 1;
		end
		imgui.SameLine();
		imgui.Checkbox("##ASItem",clamit.settings.general.autosave.item);
		imgui.SameLine();
		imgui.Text("Save after a set amount of digs.");
		imgui.SameLine();
		imgui.ShowHelp("Autosaves mean less chance of losing track of things if there's a crash.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Bucket");
		--
		if (clamit.settings.general.advanced[1]) then
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.ShowHelp("This is an advanced setting, be careful about changing it!");
			imgui.SameLine();
			imgui.SetNextItemWidth(150.0)
			imgui.InputInt("##GBCost",clamit.settings.general.bucket.cost);
			if (not clamit.settings.general.bucket.cost[1]) then
				clamit.settings.general.bucket.cost[1] = 500;
			elseif (clamit.settings.general.bucket.cost[1] > 10000) then
				clamit.settings.general.bucket.cost[1] = 10000;
			elseif (clamit.settings.general.bucket.cost[1] < 1) then
				clamit.settings.general.bucket.cost[1] = 1;
			end
			imgui.SameLine();
			imgui.Text("The price of a bucket.");
		end
		--
		if (clamit.settings.general.advanced[1]) then
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.ShowHelp("This is an advanced setting, be careful about changing it!");
			imgui.SameLine();
			imgui.SetNextItemWidth(150.0)
			imgui.InputInt("##GBCapacity",clamit.settings.general.bucket.capacity);
			if (not clamit.settings.general.bucket.capacity[1]) then
				clamit.settings.general.bucket.capacity[1] = 50;
			elseif (clamit.settings.general.bucket.capacity[1] > 1000) then
				clamit.settings.general.bucket.capacity[1] = 1000;
			elseif (clamit.settings.general.bucket.capacity[1] < 1) then
				clamit.settings.general.bucket.capacity[1] = 1;
			end
			imgui.SameLine();
			imgui.Text("The weight per bucket upgrade.");
		end
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##GBSubtract",clamit.settings.general.bucket.subtract_cost);
		imgui.SameLine();
		imgui.Text("Subtract bucket price from session value display.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##GBVVLow",clamit.settings.general.bucket.vendor_value_low);
		imgui.SameLine();
		imgui.Text("Use Bibiki Bay vendor values for value calculations?.");
		imgui.SameLine();
		imgui.ShowHelp("Prices are either 2.5% or 10% higher in a city where you have Fame 4+");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("???");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##GVerb",clamit.settings.general.verbose);
		imgui.SameLine();
		imgui.Text("Verbose mode.");
		imgui.SameLine();
		imgui.ShowHelp("Lots of annoying messages in chat about things that happened.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##GAdv",clamit.settings.general.advanced);
		imgui.SameLine();
		imgui.Text("Advanced.");
		imgui.SameLine();
		imgui.ShowHelp("Various advanced settings options.");
		--
		if (clamit.settings.general.advanced[1]) then
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.ShowHelp("This is an advanced setting, be careful about changing it!");
			imgui.SameLine();
			imgui.SetNextItemWidth(150.0)
			imgui.Checkbox("##GDEE",clamit.settings.general.easter_eggs);
			imgui.SameLine();
			imgui.Text("???");
		end
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.EndTable();
	end
end
local function render_config_display()
	if (imgui.BeginTable("##ConfigBodyDisplay", 1, bit.bor(ImGuiTableFlags_None))) then
		imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthStretch);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Display");
		--
		imgui.EndTable();
	end
end
local function render_config_colors()
	if (imgui.BeginTable("##ConfigBodyColors", 1, bit.bor(ImGuiTableFlags_None))) then
		imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthStretch);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Color Settings");
		imgui.Text();
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Dig Timer");
		imgui.Text("Dig coundown color:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CDTimer",clamit.settings.dig_timer.color);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Color by Weight");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##CWEn",clamit.settings.weights.enabled);
		imgui.SameLine();
		imgui.Text("Enabled.");
		imgui.SameLine();
		imgui.ShowHelp("These colors are also used for the Break Chance display.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Default color:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CWDef",clamit.settings.weights.colors.default);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Super Low Risk:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CWSLow",clamit.settings.weights.colors.super_low);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CWSLowTH",clamit.settings.weights.super_low);
		if (not clamit.settings.weights.super_low[1]) then
			clamit.settings.weights.super_low[1] = 35;
		elseif (clamit.settings.weights.super_low[1] > 100) then
			clamit.settings.weights.super_low[1] = 100;
		elseif (clamit.settings.weights.super_low[1] < 0) then
			clamit.settings.weights.super_low[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If remaining weight is less than this, use this color. Horizon will also use this as a default color. Default: Igneous Rock weight.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Low Risk:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CWLow",clamit.settings.weights.colors.low);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CWLowTH",clamit.settings.weights.low);
		if (not clamit.settings.weights.low[1]) then
			clamit.settings.weights.low[1] = 20;
		elseif (clamit.settings.weights.low[1] > 100) then
			clamit.settings.weights.low[1] = 100;
		elseif (clamit.settings.weights.low[1] < 0) then
			clamit.settings.weights.low[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If remaining weight is less than this, use this color. Default: Tropical Clam weight.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Medium Risk:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CWMid",clamit.settings.weights.colors.mid);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CWMidTH",clamit.settings.weights.mid);
		if (not clamit.settings.weights.mid[1]) then
			clamit.settings.weights.mid[1] = 11;
		elseif (clamit.settings.weights.mid[1] > 100) then
			clamit.settings.weights.mid[1] = 100;
		elseif (clamit.settings.weights.mid[1] < 0) then
			clamit.settings.weights.mid[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If remaining weight is less than this, use this color. Default: Jacknife weight.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("High Risk:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CWHigh",clamit.settings.weights.colors.high);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CWHighTH",clamit.settings.weights.high);
		if (not clamit.settings.weights.high[1]) then
			clamit.settings.weights.high[1] = 7;
		elseif (clamit.settings.weights.high[1] > 100) then
			clamit.settings.weights.high[1] = 100;
		elseif (clamit.settings.weights.high[1] < 0) then
			clamit.settings.weights.high[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If remaining weight is less than this, use this color. Default: Pebble weight.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Full Bucket:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CWFull",clamit.settings.weights.colors.full);
		imgui.SameLine();
		if (clamit.settings.general.advanced[1]) then
			imgui.ShowHelp("This is an advanced setting, be careful about changing it!");
			imgui.SameLine();
			imgui.SetNextItemWidth(100.0)
			imgui.InputInt("##CWFullTH",clamit.settings.weights.full);
			if (not clamit.settings.weights.full[1]) then
				clamit.settings.weights.full[1] = 5;
			elseif (clamit.settings.weights.full[1] > 100) then
				clamit.settings.weights.full[1] = 100;
			elseif (clamit.settings.weights.full[1] < 0) then
				clamit.settings.weights.full[1] = 0;
			end
		else
			imgui.Text(" " .. clamit.settings.weights.full[1] .. " ");
		end
		imgui.SameLine();
		imgui.ShowHelp("If remaining weight is less than or equal to this, the bucket counts as full, use this color. Default: 5");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Color by Item Value");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##CIVEn",clamit.settings.values.items.enabled);
		imgui.SameLine();
		imgui.Text("Enabled.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Default color:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CIVDef",clamit.settings.values.items.colors.default);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Super Low Value:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CIVSLow",clamit.settings.values.items.colors.super_low);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CIVSLowTH",clamit.settings.values.items.super_low);
		if (not clamit.settings.values.items.super_low[1]) then
			clamit.settings.values.items.super_low[1] = 5;
		elseif (clamit.settings.values.items.super_low[1] < 0) then
			clamit.settings.values.items.super_low[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If the item value is less than this, use this color. Default: 5");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Low Tier Value:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CIVLow",clamit.settings.values.items.colors.low);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CIVLowTH",clamit.settings.values.items.low);
		if (not clamit.settings.values.items.low[1]) then
			clamit.settings.values.items.low[1] = 1000;
		elseif (clamit.settings.values.items.low[1] < 0) then
			clamit.settings.values.items.low[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If the item value is greater than or equal to this, use this color. Default: 1000.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Mid Tier Value:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CIVMid",clamit.settings.values.items.colors.mid);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CIVMidTH",clamit.settings.values.items.mid);
		if (not clamit.settings.values.items.mid[1]) then
			clamit.settings.values.items.mid[1] = 2000;
		elseif (clamit.settings.values.items.mid[1] < 0) then
			clamit.settings.values.items.mid[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If the item value is greater than or equal to this, use this color. Default: 2000.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("High Tier Value:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CIVHigh",clamit.settings.values.items.colors.high);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CIVHighTH",clamit.settings.values.items.high);
		if (not clamit.settings.values.items.high[1]) then
			clamit.settings.values.items.high[1] = 5000;
		elseif (clamit.settings.values.items.high[1] < 0) then
			clamit.settings.values.items.high[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If the item value is greater than or equal to this, use this color. Default: 5000.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Color by Bucket Value");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##CBVEn",clamit.settings.values.bucket.enabled);
		imgui.SameLine();
		imgui.Text("Enabled.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Default color:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CBVDef",clamit.settings.values.bucket.colors.default);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Super Low Value:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CBVSLow",clamit.settings.values.bucket.colors.super_low);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CBVSLowTH",clamit.settings.values.bucket.super_low);
		if (not clamit.settings.values.bucket.super_low[1]) then
			clamit.settings.values.bucket.super_low[1] = 5;
		elseif (clamit.settings.values.bucket.super_low[1] < 0) then
			clamit.settings.values.bucket.super_low[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If the bucket value is less than this, use this color. Default: 5");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Low Tier Value:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CBVLow",clamit.settings.values.bucket.colors.low);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CBVLowTH",clamit.settings.values.bucket.low);
		if (not clamit.settings.values.bucket.low[1]) then
			clamit.settings.values.bucket.low[1] = 1000;
		elseif (clamit.settings.values.bucket.low[1] < 0) then
			clamit.settings.values.bucket.low[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If the bucket value is greater than or equal to this, use this color. Default: 1000.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Mid Tier Value:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CBVMid",clamit.settings.values.bucket.colors.mid);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CBVMidTH",clamit.settings.values.bucket.mid);
		if (not clamit.settings.values.bucket.mid[1]) then
			clamit.settings.values.bucket.mid[1] = 2000;
		elseif (clamit.settings.values.bucket.mid[1] < 0) then
			clamit.settings.values.bucket.mid[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If the bucket value is greater than or equal to this, use this color. Default: 2000.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("High Tier Value:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CBVHigh",clamit.settings.values.bucket.colors.high);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CBVHighTH",clamit.settings.values.bucket.high);
		if (not clamit.settings.values.bucket.high[1]) then
			clamit.settings.values.bucket.high[1] = 5000;
		elseif (clamit.settings.values.bucket.high[1] < 0) then
			clamit.settings.values.bucket.high[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If the bucket value is greater than or equal to this, use this color. Default: 5000.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Color by Session Value");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##CSVEn",clamit.settings.values.session.enabled);
		imgui.SameLine();
		imgui.Text("Enabled.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Default color:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CSVDef",clamit.settings.values.session.colors.default);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Super Low Value:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CSVSLow",clamit.settings.values.session.colors.super_low);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CSVSLowTH",clamit.settings.values.session.super_low);
		if (not clamit.settings.values.session.super_low[1]) then
			clamit.settings.values.session.super_low[1] = 0;
		elseif (clamit.settings.values.session.super_low[1] < 0) then
			clamit.settings.values.session.super_low[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If the session value is less than this, use this color. Default: 0 (For negative values).");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Low Tier Value:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CSVLow",clamit.settings.values.session.colors.low);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CSVLowTH",clamit.settings.values.session.low);
		if (not clamit.settings.values.session.low[1]) then
			clamit.settings.values.session.low[1] = 25000;
		elseif (clamit.settings.values.session.low[1] < 0) then
			clamit.settings.values.session.low[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If the session value is greater than or equal to this, use this color. Default: 25000.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("Mid Tier Value:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CSVMid",clamit.settings.values.session.colors.mid);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CSVMidTH",clamit.settings.values.session.mid);
		if (not clamit.settings.values.session.mid[1]) then
			clamit.settings.values.session.mid[1] = 50000;
		elseif (clamit.settings.values.session.mid[1] < 0) then
			clamit.settings.values.session.mid[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If the session value is greater than or equal to this, use this color. Default: 50000.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Text("High Tier Value:");
		imgui.SetNextItemWidth(150.0)
		imgui.ColorEdit4("##CSVHigh",clamit.settings.values.session.colors.high);
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		imgui.InputInt("##CSVHighTH",clamit.settings.values.session.high);
		if (not clamit.settings.values.session.high[1]) then
			clamit.settings.values.session.high[1] = 100000;
		elseif (clamit.settings.values.session.high[1] < 0) then
			clamit.settings.values.session.high[1] = 0;
		end
		imgui.SameLine();
		imgui.ShowHelp("If the session value is greater than or equal to this, use this color. Default: 100000.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		--
		imgui.EndTable();
	end
end
local function render_config_sounders()
	local volume_text = T {
		[1] = "Low",
		[2] = "Medium",
		[3] = "High",
	};
	if (imgui.BeginTable("##ConfigBodySounders", 1, bit.bor(ImGuiTableFlags_None))) then
		imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthStretch);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Sounders");
		imgui.Text("");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Dig Ready");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##SCDig",clamit.settings.sounders.dig_ready.enabled);
		imgui.SameLine();
		imgui.Text("Enable sounder.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##SCDigRandom",clamit.settings.sounders.dig_ready.randomize);
		imgui.SameLine();
		imgui.Text("Randomize.");
		imgui.SameLine();
		imgui.ShowHelp("Choose a random sound every time.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SetNextItemWidth(250.0)
		if (imgui.BeginCombo("##CSDigReady",clamit.settings.sounders.dig_ready.sound_list[clamit.settings.sounders.dig_ready.sound_selected[1]].label)) then
			for i = 1, clamit.settings.sounders.dig_ready.sound_count do
				local is_selected = i == clamit.settings.sounders.dig_ready.sound_selected[1];
				if (imgui.Selectable(clamit.settings.sounders.dig_ready.sound_list[i].label , is_selected)) then
					clamit.settings.sounders.dig_ready.sound_selected[1] = i;
				end
				if (is_selected) then imgui.SetItemDefaultFocus(); end
			end
			imgui.EndCombo();
		end
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		if (imgui.BeginCombo("##CSDigReadyVol",volume_text[clamit.settings.sounders.dig_ready.sound_volume])) then
			for i = 1, 3 do
				local is_selected = i == clamit.settings.sounders.dig_ready.sound_volume;
				if (imgui.Selectable(volume_text[i] , is_selected)) then
					clamit.settings.sounders.dig_ready.sound_volume = i;
				end
				if (is_selected) then imgui.SetItemDefaultFocus(); end
			end
			imgui.EndCombo();
		end
		imgui.SameLine();
		if (imgui.ArrowButton("##CSDigReadyTest", ImGuiDir_Right)) then
			play_sound(clamit.settings.sounders.dig_ready);
		end
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Bucket Full");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##SCFull",clamit.settings.sounders.bucket_full.enabled);
		imgui.SameLine();
		imgui.Text("Enable sounder.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##SCFullRandom",clamit.settings.sounders.bucket_full.randomize);
		imgui.SameLine();
		imgui.Text("Randomize.");
		imgui.SameLine();
		imgui.ShowHelp("Choose a random sound every time.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SetNextItemWidth(250.0)
		if (imgui.BeginCombo("##CSFullBucket",clamit.settings.sounders.bucket_full.sound_list[clamit.settings.sounders.bucket_full.sound_selected[1]].label)) then
			for i = 1, clamit.settings.sounders.bucket_full.sound_count do
				local is_selected = i == clamit.settings.sounders.bucket_full.sound_selected[1];
				if (imgui.Selectable(clamit.settings.sounders.bucket_full.sound_list[i].label , is_selected)) then
					clamit.settings.sounders.bucket_full.sound_selected[1] = i;
				end
				if (is_selected) then imgui.SetItemDefaultFocus(); end
			end
			imgui.EndCombo();
		end
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		if (imgui.BeginCombo("##CSFullBucketVol",volume_text[clamit.settings.sounders.bucket_full.sound_volume])) then
			for i = 1, 3 do
				local is_selected = i == clamit.settings.sounders.bucket_full.sound_volume;
				if (imgui.Selectable(volume_text[i] , is_selected)) then
					clamit.settings.sounders.bucket_full.sound_volume = i;
				end
				if (is_selected) then imgui.SetItemDefaultFocus(); end
			end
			imgui.EndCombo();
		end
		imgui.SameLine();
		if (imgui.ArrowButton("##CSFullBucketTest", ImGuiDir_Right)) then
			play_sound(clamit.settings.sounders.bucket_full);
		end
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Bucket Break");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##SCBreak",clamit.settings.sounders.bucket_break.enabled);
		imgui.SameLine();
		imgui.Text("Enable sounder.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Checkbox("##SCBreakRandom",clamit.settings.sounders.bucket_break.randomize);
		imgui.SameLine();
		imgui.Text("Randomize.");
		imgui.SameLine();
		imgui.ShowHelp("Choose a random sound every time.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SetNextItemWidth(250.0)
		if (imgui.BeginCombo("##CSBreakBucket",clamit.settings.sounders.bucket_break.sound_list[clamit.settings.sounders.bucket_break.sound_selected[1]].label)) then
			for i = 1, clamit.settings.sounders.bucket_break.sound_count do
				local is_selected = i == clamit.settings.sounders.bucket_break.sound_selected[1];
				if (imgui.Selectable(clamit.settings.sounders.bucket_break.sound_list[i].label , is_selected)) then
					clamit.settings.sounders.bucket_break.sound_selected[1] = i;
				end
				if (is_selected) then imgui.SetItemDefaultFocus(); end
			end
			imgui.EndCombo();
		end
		imgui.SameLine();
		imgui.SetNextItemWidth(100.0)
		if (imgui.BeginCombo("##CSBreakBucketVol",volume_text[clamit.settings.sounders.bucket_break.sound_volume])) then
			for i = 1, 3 do
				local is_selected = i == clamit.settings.sounders.bucket_break.sound_volume;
				if (imgui.Selectable(volume_text[i] , is_selected)) then
					clamit.settings.sounders.bucket_break.sound_volume = i;
				end
				if (is_selected) then imgui.SetItemDefaultFocus(); end
			end
			imgui.EndCombo();
		end
		imgui.SameLine();
		if (imgui.ArrowButton("##CSBreakBucketTest", ImGuiDir_Right)) then
			play_sound(clamit.settings.sounders.bucket_break);
		end
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.Separator();
		--
		if (clamit.settings.general.advanced[1] and clamit.settings.general.easter_eggs[1]) then
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("???");
			imgui.SameLine();
			if (imgui.ArrowButton("##CSWowTest", ImGuiDir_Right)) then
				clamit.settings.sounders.wow.enabled[1] = clamit.settings.sounders.bucket_full.enabled[1];
				clamit.settings.sounders.wow.sound_volume = clamit.settings.sounders.bucket_full.sound_volume;
				play_sound(clamit.settings.sounders.wow);
			end
			imgui.SameLine();
			if (imgui.ArrowButton("##CSHahaTest", ImGuiDir_Right)) then
				clamit.settings.sounders.haha.enabled[1] = clamit.settings.sounders.bucket_break.enabled[1];
				clamit.settings.sounders.haha.sound_volume = clamit.settings.sounders.bucket_break.sound_volume;
				play_sound(clamit.settings.sounders.haha);
			end
		end
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		--
		imgui.EndTable();
	end
end
local function render_config_items()
	if (imgui.BeginTable("##ConfigBodyItems", 1, bit.bor(ImGuiTableFlags_None))) then
		imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthStretch);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Items");
		--
		local this_columns = 8;
		if (clamit.settings.general.advanced[1]) then
			this_columns = this_columns + 3;
		end
		if (imgui.BeginTable("##ConfigItemsList", this_columns, bit.bor(ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_RowBg))) then
			imgui.TableSetupColumn('');
			imgui.TableSetupColumn('');
			imgui.TableSetupColumn('Item');
			if (clamit.settings.general.advanced[1]) then
				imgui.TableSetupColumn('');
			end
			imgui.TableSetupColumn('Weight');
			if (clamit.settings.general.advanced[1]) then
				imgui.TableSetupColumn('');
			end
			imgui.TableSetupColumn('Low');
			if (clamit.settings.general.advanced[1]) then
				imgui.TableSetupColumn('');
			end
			imgui.TableSetupColumn('High');
			imgui.TableSetupColumn('AH');
			imgui.TableSetupColumn('');
			imgui.TableHeadersRow();
			local icon_small_size = 16;
			if (clamit.settings.display.bucket_window.scale[1] ~= 1) then
				--icon_full_size = math.floor(icon_full_size * clamit.settings.display.bucket_window.scale[1]);
				icon_small_size = math.floor(icon_small_size * clamit.settings.display.bucket_window.scale[1]);
			end
			for i = 1, data.item_count do
				local this_item = data.sorting.alpha_asc[i];
				local this_color = clamit.settings.display.config_window.font_color;
				if (not clamit.settings.item_list[this_item].enabled[1]) then
					this_color = clamit.settings.display.config_window.disabled_color;
				end
				imgui.TableNextRow();
				imgui.TableNextColumn();
				if (clamit.settings.general.advanced[1]) then
					imgui.ShowHelp("This is an advanced setting, be careful about changing it!");
					imgui.SameLine();
					imgui.Checkbox("##EnableItem_" .. i,clamit.settings.item_list[this_item].enabled);
				else
				end
				imgui.TableNextColumn();
				if (clamit.item_icons[this_item].Pointer ~= nil) then imgui.Image(clamit.item_icons[this_item].Pointer, {icon_small_size, icon_small_size}); end
				imgui.TableNextColumn();
				imgui.TextColored(this_color,clamit.settings.item_list[this_item].name);
				imgui.TableNextColumn();
				if (clamit.settings.general.advanced[1]) then
					imgui.ShowHelp("This is an advanced setting, be careful about changing it!");
					imgui.TableNextColumn();
					imgui.SetNextItemWidth(100.0)
					imgui.InputInt("##ItemWeight_" .. i,clamit.settings.item_list[this_item].weight);
					if (not clamit.settings.item_list[this_item].weight[1]) then
						clamit.settings.item_list[this_item].weight[1] = 0;
					elseif (clamit.settings.item_list[this_item].weight[1] < 0) then
						clamit.settings.item_list[this_item].weight[1] = 0;
					end
				else
					imgui.TextColored(this_color,clamit.settings.item_list[this_item].weight[1]);
				end
				imgui.TableNextColumn();
				if (clamit.settings.general.advanced[1]) then
					imgui.ShowHelp("This is an advanced setting, be careful about changing it!");
					imgui.TableNextColumn();
					imgui.SetNextItemWidth(100.0)
					imgui.InputInt("##ItemVLow_" .. i,clamit.settings.item_list[this_item].vendor_low);
					if (not clamit.settings.item_list[this_item].vendor_low[1]) then
						clamit.settings.item_list[this_item].vendor_low[1] = 0;
					elseif (clamit.settings.item_list[this_item].vendor_low[1] < 0) then
						clamit.settings.item_list[this_item].vendor_low[1] = 0;
					end
				else
					imgui.TextColored(this_color,format_int(clamit.settings.item_list[this_item].vendor_low[1]) .. 'g');
				end
				imgui.TableNextColumn();
				if (clamit.settings.general.advanced[1]) then
					imgui.ShowHelp("This is an advanced setting, be careful about changing it!");
					imgui.TableNextColumn();
					imgui.SetNextItemWidth(100.0)
					imgui.InputInt("##ItemVHigh_" .. i,clamit.settings.item_list[this_item].vendor_high);
					if (not clamit.settings.item_list[this_item].vendor_high[1]) then
						clamit.settings.item_list[this_item].vendor_high[1] = 0;
					elseif (clamit.settings.item_list[this_item].vendor_high[1] < 0) then
						clamit.settings.item_list[this_item].vendor_high[1] = 0;
					end
				else
					imgui.TextColored(this_color,format_int(clamit.settings.item_list[this_item].vendor_high[1]) .. 'g');
				end
				imgui.TableNextColumn();
				--imgui.Text(format_int(clamit.settings.item_list[this_item].ah_value[1]) .. 'g');
				if (clamit.settings.item_list[this_item].enabled[1]) then
					imgui.SetNextItemWidth(100.0)
					imgui.InputInt("##ItemAHVal_" .. i,clamit.settings.item_list[this_item].ah_value);
					if (not clamit.settings.item_list[this_item].ah_value[1]) then
						clamit.settings.item_list[this_item].ah_value[1] = 0;
					elseif (clamit.settings.item_list[this_item].ah_value[1] < 0) then
						clamit.settings.item_list[this_item].ah_value[1] = 0;
					end
				else
					imgui.TextColored(this_color,format_int(clamit.settings.item_list[this_item].ah_value[1]) .. 'g');
				end
				imgui.TableNextColumn();
				if (clamit.settings.item_list[this_item].enabled[1]) then
					imgui.Checkbox("##ItemAH_" .. i,clamit.settings.item_list[this_item].use_ah);
					imgui.SameLine();
					imgui.ShowHelp("Use AH value for value calculations. Values of 0 default beck to vendor values.");
				end
			end
			imgui.EndTable();
		end
		imgui.EndTable();
	end
end
local function render_config_stats()
	if (imgui.BeginTable("##ConfigBodyStats", 1, bit.bor(ImGuiTableFlags_None))) then
		imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthStretch);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Statistics");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		if (imgui.BeginTable("##ConfigStatsMain", 2, bit.bor(ImGuiTableFlags_SizingFixedFit))) then
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.SeparatorText("Revenue:")
			imgui.TableNextColumn();
			imgui.ShowHelp("Based on item value when the bucket was turned in.");
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Gained:")
			imgui.TableNextColumn();
			imgui.Text(format_int(clamit.settings.statistics.value.gained) .. 'g');
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Lost:")
			imgui.TableNextColumn();
			imgui.Text(format_int(clamit.settings.statistics.value.lost) .. 'g');
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Bucket Cost:")
			imgui.TableNextColumn();
			imgui.Text(format_int(clamit.settings.statistics.buckets.total * clamit.settings.general.bucket.cost[1]) .. 'g');
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Separator();
			imgui.TableNextColumn();
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.SeparatorText("Items Dug:")
			imgui.TableNextColumn();
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Total:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.items.total);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Gained:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.items.gained);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Lost:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.items.lost);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Separator();
			imgui.TableNextColumn();
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.SeparatorText("One Bucket Records:")
			imgui.TableNextColumn();
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Items Gained:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.items.highest.gained);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Items Lost:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.items.highest.lost);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Unique Gained:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.items.highest.unique_gained);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Unique Lost:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.items.highest.unique_lost);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Value Gained:")
			imgui.TableNextColumn();
			imgui.Text(format_int(clamit.settings.statistics.value.highest.gained) .. 'g');
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Value Lost:")
			imgui.TableNextColumn();
			imgui.Text(format_int(clamit.settings.statistics.value.highest.lost) .. 'g');
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Separator();
			imgui.TableNextColumn();
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.SeparatorText("Buckets:")
			imgui.TableNextColumn();
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Total Buckets:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.total);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Total Breaks:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.breaks.total);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Total Upgrades:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.upgrades.total);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Total Turnins:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.turnins.total);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Separator();
			imgui.TableNextColumn();
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.SeparatorText("Bucket Breaks:")
			imgui.TableNextColumn();
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("1st Bucket Breaks:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.breaks.first);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("2nd Bucket Breaks:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.breaks.second);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("3rd Bucket Breaks:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.breaks.third);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("4th Bucket Breaks:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.breaks.fourth);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Incident Breaks:")
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.breaks.fourth);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Separator();
			imgui.TableNextColumn();
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.SeparatorText("Bucket Upgrades:")
			imgui.TableNextColumn();
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Upgrade to 2nd:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.upgrades.first);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Upgrade to 3rd:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.upgrades.second);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("Upgrade to 4th:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.upgrades.third);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Separator();
			imgui.TableNextColumn();
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.SeparatorText("Bucket Turnins:")
			imgui.TableNextColumn();
			--imgui.ShowHelp("Buckets turned in without adding any new digs.");
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("1st Bucket:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.turnins.first);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("2nd Bucket:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.turnins.second);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("3rd Bucket:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.turnins.third);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("4th Bucket:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.turnins.fourth);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Separator();
			imgui.TableNextColumn();
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.SeparatorText("Empty Turnins:")
			imgui.TableNextColumn();
			imgui.ShowHelp("Buckets turned in without adding any new digs.");
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("1st Bucket:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.turnins.empty.first);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("2nd Bucket:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.turnins.empty.second);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("3rd Bucket:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.turnins.empty.third);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Text("4th Bucket:");
			imgui.TableNextColumn();
			imgui.Text(clamit.settings.statistics.buckets.turnins.empty.fourth);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.Separator();
			imgui.TableNextColumn();
			if (clamit.settings.statistics.just_one_more > 0 or clamit.settings.statistics.just_one_oops > 0) then
				imgui.TableNextRow();
				imgui.TableNextColumn();
				imgui.SeparatorText("???")
				imgui.TableNextColumn();
				imgui.ShowHelp("Times you proved your Genius by digging after the bucket was full.");
				if (clamit.settings.statistics.just_one_more > 0) then
					imgui.TableNextRow();
					imgui.TableNextColumn();
					imgui.Text("Just One More:");
					imgui.TableNextColumn();
					imgui.Text(clamit.settings.statistics.just_one_more);
				end
				if (clamit.settings.statistics.just_one_oops > 0) then
					imgui.TableNextRow();
					imgui.TableNextColumn();
					imgui.Text("Just One Oops!:");
					imgui.TableNextColumn();
					imgui.Text(clamit.settings.statistics.just_one_oops);
				end
				imgui.TableNextRow();
				imgui.TableNextColumn();
				imgui.Separator();
				imgui.TableNextColumn();
			end
			imgui.EndTable();
		end
		imgui.EndTable();
	end
end
local function render_config_item_stats()
	if (imgui.BeginTable("##ConfigBodyItemStats", 1, bit.bor(ImGuiTableFlags_None))) then
		imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthStretch);
		--
		local this_total_value = 0;
		for i = 1, data.item_count do
			local this_item = data.sorting.alpha_asc[i];
			if (clamit.settings.item_list[this_item].enabled[1]) then
				local this_value = 0;
				if (clamit.settings.item_list[this_item].use_ah[1] and clamit.settings.item_list[this_item].ah_value[1] > 0) then
					this_value = clamit.settings.item_list[this_item].ah_value[1];
				elseif (clamit.settings.general.bucket.vendor_value_low[1]) then
					this_value = clamit.settings.item_list[this_item].vendor_low[1];
				else
					this_value = clamit.settings.item_list[this_item].vendor_high[1];
				end
				this_total_value = this_total_value + (this_value * clamit.settings.item_list[this_item].lifetime.gained);
			end
		end
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Item Statistics: " .. format_int(clamit.settings.statistics.items.total) .. " items, " .. format_int(this_total_value) .. "g.");
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		if (imgui.BeginTable("##ConfigStatsItemsList", 12, bit.bor(ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_RowBg))) then
			local icon_small_size = 16;
			if (clamit.settings.display.bucket_window.scale[1] ~= 1) then
				--icon_full_size = math.floor(icon_full_size * clamit.settings.display.bucket_window.scale[1]);
				icon_small_size = math.floor(icon_small_size * clamit.settings.display.bucket_window.scale[1]);
			end
			imgui.TableNextRow();
			imgui.TableNextColumn();
			imgui.TableNextColumn();
			imgui.Text("Item");
			imgui.TableNextColumn();
			imgui.ShowHelp("Drop Chance");
			imgui.TableNextColumn();
			imgui.ShowHelp("Total Seen");
			imgui.TableNextColumn();
			imgui.ShowHelp("Total Gained");
			imgui.TableNextColumn();
			imgui.ShowHelp("Total Lost");
			imgui.TableNextColumn();
			imgui.ShowHelp("Highest Seen in One Bucket");
			imgui.TableNextColumn();
			imgui.ShowHelp("Highest Gained from One Bucket");
			imgui.TableNextColumn();
			imgui.ShowHelp("Bucket Breaks");
			imgui.TableNextColumn();
			imgui.ShowHelp("Value Gained");
			imgui.TableNextColumn();
			imgui.ShowHelp("Percentage of Total Value Gained");
			imgui.TableNextColumn();
			for i = 1, data.item_count do
				local this_item = data.sorting.alpha_asc[i];
				local this_color = clamit.settings.display.config_window.font_color;
				if (clamit.settings.item_list[this_item].enabled[1]) then
					imgui.TableNextRow();
					imgui.TableNextColumn();
					if (clamit.item_icons[this_item].Pointer ~= nil) then imgui.Image(clamit.item_icons[this_item].Pointer, {icon_small_size, icon_small_size}); end
					imgui.TableNextColumn();
					imgui.TextColored(this_color,clamit.settings.item_list[this_item].name);
					imgui.TableNextColumn();
					-- Percentage calculation
					if (clamit.settings.statistics.items.total > 0) then
						local this_chance = (clamit.settings.item_list[this_item].lifetime.seen / clamit.settings.statistics.items.total) * 100;
						imgui.TextColored(this_color,string.format("%.2f",this_chance) .. '%');
					else
						imgui.TextColored(this_color,'N/A');
					end
					imgui.TableNextColumn();
					imgui.TextColored(this_color," "..format_int(clamit.settings.item_list[this_item].lifetime.seen));
					imgui.TableNextColumn();
					imgui.TextColored(this_color," "..format_int(clamit.settings.item_list[this_item].lifetime.gained));
					imgui.TableNextColumn();
					imgui.TextColored(this_color," "..format_int(clamit.settings.item_list[this_item].lifetime.seen - clamit.settings.item_list[this_item].lifetime.gained));
					imgui.TableNextColumn();
					imgui.TextColored(this_color," "..format_int(clamit.settings.item_list[this_item].lifetime.one_bucket));
					imgui.TableNextColumn();
					imgui.TextColored(this_color," "..format_int(clamit.settings.item_list[this_item].lifetime.one_bucket_gained));
					imgui.TableNextColumn();
					imgui.TextColored(this_color," "..format_int(clamit.settings.item_list[this_item].lifetime.last_straw));
					imgui.TableNextColumn();
					local this_value = 0;
					if (clamit.settings.item_list[this_item].use_ah[1] and clamit.settings.item_list[this_item].ah_value[1] > 0) then
						this_value = clamit.settings.item_list[this_item].ah_value[1];
					elseif (clamit.settings.general.bucket.vendor_value_low[1]) then
						this_value = clamit.settings.item_list[this_item].vendor_low[1];
					else
						this_value = clamit.settings.item_list[this_item].vendor_high[1];
					end
					this_value = this_value * clamit.settings.item_list[this_item].lifetime.gained;
					imgui.TextColored(this_color,format_int(this_value) .. 'g');
					imgui.TableNextColumn();
					if (clamit.settings.statistics.items.total > 0) then
						if (this_value > 0) then
							imgui.TextColored(this_color,string.format("%.2f",(this_value / this_total_value) * 100) .. "%");
						else
							imgui.TextColored(this_color,'0.00%');
						end
					else
						imgui.TextColored(this_color,'N/A');
					end
					imgui.TableNextColumn();
				end
			end
			imgui.EndTable();
		end

		imgui.EndTable();
	end
end
local function render_commands()
	if (imgui.BeginTable("##ConfigBodyCommands", 1, bit.bor(ImGuiTableFlags_None))) then
		imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthStretch);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Commands");
		imgui.Text();
		imgui.Text("/clamit  or  /clamit config");
		imgui.Text("Toggle open this config window.");
		imgui.Text();
		imgui.Text("/clamit help");
		imgui.Text("Print this list in the chat.");
		imgui.Text();
		imgui.Text("/clamit show");
		imgui.Text("Show the bucket window (unless it's disabled out of area).");
		imgui.Text();
		imgui.Text("/clamit show override");
		imgui.Text("Show the bucket window, even if it's disabled out of area (will revert when it times out).");
		imgui.Text();
		imgui.Text("/clamit hide");
		imgui.Text("Hide the bucket window (unless the config window is open).");
		imgui.Text();
		imgui.Text("/clamit clear");
		imgui.Text("Clear the contents of the bucket and session, and clear the session timer.");
		imgui.Text();
		imgui.Text("/clamit clear bucket");
		imgui.Text("Clear the contents of the bucket.");
		imgui.Text();
		imgui.Text("/clamit clear session");
		imgui.Text("Clear the contents of the session, and clear the session timer.");
		imgui.Text();
		imgui.Text("/clamit save");
		imgui.Text("Save the current settings / data.");
		imgui.Text();
		imgui.Text("/clamit load");
		imgui.Text("Load the settings / data, losing any changes not saved.");
		imgui.Text();
		imgui.Text("/clamit defaults");
		imgui.Text("Reset the settings back to default. Does not clear statistics data.");
		imgui.EndTable();
	end
end
local function render_notes()
	if (imgui.BeginTable("##ConfigBodyNotes", 1, bit.bor(ImGuiTableFlags_None))) then
		imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthStretch);
		--
		imgui.TableNextRow();
		imgui.TableNextColumn();
		imgui.SeparatorText("Notes");
		imgui.Text();
		imgui.Text("If the bucket details are incorrect, talking to the NPC (Toh Zonikki) can help fix them.");
		imgui.Text("When you first talk to them it will detect if you have a bucket.");
		imgui.Text("If you do have a bucket and you choose the default talk option, it will update the weight.");
		imgui.Text("At the same time it'll make the best-guess for the bucket capacity - it'll be accurate so long as it's not in the weight range of being 'full'.");
		imgui.Text("(eg. 45-50 could be the initial bucket, or it could be the next bucket up).");
		imgui.Text();
		imgui.Text("It will also detect if you zone, and clear the bucket if it's active.");
		imgui.Text("Zoning loses the items, but the bucket maintains it's current weight & capacity.");
		imgui.Text("You can add more into it when you come back, but the previous items are gone, and you only have the remaining weight you did before you zoned.");
		imgui.Text();
		imgui.Text("The biggest bucket always has a chance to break from an 'incident'.");
		imgui.Text("It's reported to be ~20% without HQ clamming top, and ~10% with. This does not get shown in the break chance.");
		imgui.Text();
		imgui.SeparatorText("Known Issues:");
		imgui.Text("- It does not deal well with changing characters at the moment, and will lose bucket and session contents. Best to do your turnin before switching.");
		imgui.Text("- The statistics data is per character, so if you use multiple characters you'll have to do a bit of digging to get accurate info.");
		imgui.Text("  (It may also pre-populate existing stats onto a character that hasn't loaded the addon before).");
		imgui.EndTable();
	end
end
local function render_config()
	if (not clamit.settings.display.config_window.visible[1]) then return; end
	imgui.SetNextWindowSize({-1, -1}, ImGuiCond_Once);
	if (imgui.Begin('Clamit##Config', clamit.settings.display.config_window.visible[1], ImGuiWindowFlags_NoFlags)) then
		if (imgui.BeginTable("##ConfigHeaderButtons", 1, bit.bor(ImGuiTableFlags_None))) then
			imgui.TableNextRow();
			imgui.TableNextColumn();
				if (imgui.Button('Clear Bucket')) then
					clear_bucket();
					add_message("Cleared Bucket.",false);
				end
				imgui.SameLine();
				if (imgui.Button('Clear Session')) then
					clear_session(true);
					add_message("Cleared Session.",false);
				end
				imgui.SameLine();
				if (imgui.Button('Clear Both')) then
					clear_bucket();
					clear_session(true);
					add_message("Cleared Bucket and Session.",false);
				end
				imgui.SameLine();
				if (imgui.Button('Save Settings')) then
					settings.save();
					add_message("Settings saved.");
				end
				imgui.SameLine();
				if (imgui.Button('Load Settings')) then
					settings.load();
					add_message("Settings loaded.");
				end
				imgui.SameLine();
				if (imgui.Button('Default Settings')) then
					reset_defaults();
					add_message("Settings reset to default, statistics data not cleared.",false);
				end
				imgui.SameLine();
				if (imgui.Button('Close')) then
					clamit.settings.display.config_window.visible[1] = false;
				end
			imgui.EndTable();
		end
		if (imgui.BeginTable("##ConfigMain", 2, bit.bor(ImGuiTableFlags_None))) then
			imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthFixed, 100);
			imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthStretch, 100);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			-- Side menu
			if (imgui.Selectable("General", clamit.settings.display.config_window.tab == 1)) then
				clamit.settings.display.config_window.tab = 1;
			end
			--[[
			if (imgui.Selectable("Display", clamit.settings.display.config_window.tab == 2)) then
				clamit.settings.display.config_window.tab = 2;
			end--]]
			if (imgui.Selectable("Colors", clamit.settings.display.config_window.tab == 3)) then
				clamit.settings.display.config_window.tab = 3;
			end
			if (imgui.Selectable("Sounders", clamit.settings.display.config_window.tab == 4)) then
				clamit.settings.display.config_window.tab = 4;
			end
			if (imgui.Selectable("Items", clamit.settings.display.config_window.tab == 5)) then
				clamit.settings.display.config_window.tab = 5;
			end
			if (imgui.Selectable("Stats", clamit.settings.display.config_window.tab == 6)) then
				clamit.settings.display.config_window.tab = 6;
			end
			if (imgui.Selectable("Item Stats", clamit.settings.display.config_window.tab == 7)) then
				clamit.settings.display.config_window.tab = 7;
			end
			if (imgui.Selectable("Commands", clamit.settings.display.config_window.tab == 8)) then
				clamit.settings.display.config_window.tab = 8;
			end
			imgui.Text();
			imgui.Text();
			if (imgui.Selectable("*Notes", clamit.settings.display.config_window.tab == 9)) then
				clamit.settings.display.config_window.tab = 9;
			end
			imgui.TableNextColumn();
			-- Actual config pages.
			if (clamit.settings.display.config_window.tab == 1) then
				render_config_general();
			elseif (clamit.settings.display.config_window.tab == 2) then
				render_config_display();
			elseif (clamit.settings.display.config_window.tab == 3) then
				render_config_colors();
			elseif (clamit.settings.display.config_window.tab == 4) then
				render_config_sounders();
			elseif (clamit.settings.display.config_window.tab == 5) then
				render_config_items();
			elseif (clamit.settings.display.config_window.tab == 6) then
				render_config_stats();
			elseif (clamit.settings.display.config_window.tab == 7) then
				render_config_item_stats();
			elseif (clamit.settings.display.config_window.tab == 8) then
				render_commands();
			elseif (clamit.settings.display.config_window.tab == 9) then
				render_notes();
			end
			imgui.EndTable();
		end
	end
	imgui.End();
end
--[[ %%RENDER BUCKET%% --]]
local function render_bucket()
	if (not clamit.settings.display.bucket_window.visible[1]) then return; end
	-- Scaling Stuff
	local icon_full_size = 44;
	local icon_small_size = 16;
	if (clamit.settings.display.bucket_window.scale[1] ~= 1) then
		icon_full_size = math.floor(icon_full_size * clamit.settings.display.bucket_window.scale[1]);
		icon_small_size = math.floor(icon_small_size * clamit.settings.display.bucket_window.scale[1]);
	end
	-- Pre-calculate the gear icons.
	local top_icon = nil;
	local bottom_icon = nil;
	local has_hq_body, has_hq_legs = check_hq(); -- Is the player wearing the HQ clamming gear?
	local player_entity = GetPlayerEntity();
	if (player_entity ~= nil) then
		clamit.current_character_race_id = player_entity.Race;
	end;
	local ismale = ((clamit.current_character_race_id % 2) == 1);
	if (has_hq_body) then
		if (ismale) then
			top_icon = clamit.gear_icons.m_top_on;
		else
			top_icon = clamit.gear_icons.f_top_on;
		end
	else
		if (ismale) then
			top_icon = clamit.gear_icons.m_top_off;
		else
			top_icon = clamit.gear_icons.f_top_off;
		end
	end
	if (has_hq_legs) then
		if (ismale) then
			bottom_icon = clamit.gear_icons.m_bottom_on;
		else
			bottom_icon = clamit.gear_icons.f_bottom_on;
		end
	else
		if (ismale) then
			bottom_icon = clamit.gear_icons.m_bottom_off;
		else
			bottom_icon = clamit.gear_icons.f_bottom_off;
		end
	end
	-- Pre-calculate the bucket status.
	local status_text = '[Unknown]';
	local status_color = clamit.settings.display.bucket_window.disabled_color;
	local weight_diff = clamit.settings.bucket.capacity - clamit.settings.bucket.weight;
	if (clamit.settings.bucket.broken and clamit.settings.bucket.active) then
		status_text = '[Broken]';
		status_color = clamit.settings.weights.colors.high;
	elseif (not clamit.settings.bucket.active) then
		status_text = '[No Bucket]';
		status_color = clamit.settings.display.bucket_window.disabled_color;
	elseif (clamit.settings.bucket.active and clamit.settings.bucket.zoned) then
		status_text = '[Zoned]';
		status_color = clamit.settings.display.bucket_window.font_color;
	else
		if (weight_diff >= 0 and weight_diff <= clamit.settings.weights.full[1]) then
			status_text = '[Full]';
			status_color = clamit.settings.weights.colors.full;
		else
			status_text = '[OK]';
			status_color = clamit.settings.weights.colors.super_low;
		end
	end
	if (not clamit.settings.weights.enabled[1]) then
		status_color = clamit.settings.display.bucket_window.font_color;
	end
	-- Pre-calculate the bucket weight.
	local weight_text = '??/??';
	local weight_color = clamit.settings.display.bucket_window.font_color;
	if (clamit.settings.bucket.broken and clamit.settings.bucket.active) then
		weight_text = '--/--';
		weight_color = clamit.settings.weights.colors.high;
	elseif (not clamit.settings.bucket.active) then
		weight_text = 'N/A';
		weight_color = clamit.settings.display.bucket_window.disabled_color;
	else
		weight_text = clamit.settings.bucket.weight .. '/' .. clamit.settings.bucket.capacity;
		if (weight_diff >= 0 and weight_diff <= clamit.settings.weights.full[1]) then
			weight_color = clamit.settings.weights.colors.full;
		elseif (weight_diff < clamit.settings.weights.high[1] and weight_diff > clamit.settings.weights.full[1]) then
			weight_color = clamit.settings.weights.colors.high;
		elseif (weight_diff < clamit.settings.weights.mid[1] and weight_diff >= clamit.settings.weights.high[1]) then
			weight_color = clamit.settings.weights.colors.mid;
		elseif (weight_diff < clamit.settings.weights.low[1] and weight_diff >= clamit.settings.weights.mid[1]) then
			weight_color = clamit.settings.weights.colors.low;
		elseif (weight_diff < clamit.settings.weights.super_low[1] and weight_diff >= clamit.settings.weights.low[1]) then
			weight_color = clamit.settings.weights.colors.super_low;
		elseif (weight_diff >= clamit.settings.weights.super_low[1]) then
			weight_color = clamit.settings.weights.colors.super_low;
		end
	end
	if (not clamit.settings.weights.enabled[1]) then
		weight_color = clamit.settings.display.bucket_window.font_color;
	end
	-- Pre-calculate the dig timer. -- Nevermind, it's simple enough to not worry about.
	-- Pre-calculate the break chance.
	local break_chance_text = 'N/A';
	local break_chance_color = clamit.settings.display.bucket_window.disabled_color;
	local break_chance_padded = false;
	if (clamit.settings.bucket.active and not clamit.settings.bucket.broken) then
		if (weight_diff < 0) then
			-- Should never get here, but just in case... We're not actually setting anything though, because the default we just set is what we want.
		elseif (weight_diff < 3) then
			-- There's less than 3 weight available, so it's a guaranteed break.
			break_chance_text = '100.00%';
			break_chance_color = clamit.settings.weights.colors.high;
		elseif (weight_diff >= 35 or (weight_diff >= 20 and clamit.horizon_server)) then
			-- No chance of breaking (35 is highest normally, 20 for Horizon).
			break_chance_text = '0.00%';
			break_chance_color = clamit.settings.weights.colors.default;
		else
			-- We actually have to calculate a percentage now...
			local this_item_count = clamit.settings.statistics.items.total;
			local this_break_count = 0;
			for i = 1, data.item_count do
				local this_item = data.sorting.alpha_asc[i];
				if (clamit.settings.item_list[this_item].enabled[1]) then
					if (clamit.settings.item_list[this_item].weight[1] > weight_diff) then
						if (clamit.settings.item_list[this_item].lifetime.seen > 0) then
							this_break_count = this_break_count + clamit.settings.item_list[this_item].lifetime.seen;
						else
							-- Because we haven't seen this item before (according to the statistics) we should pad it to make the inaccuracy slightly less bad.
							this_break_count = this_break_count + 1;
							this_item_count = this_item_count + 1;
							break_chance_padded = true;
						end
					else
						if (clamit.settings.item_list[this_item].lifetime.seen < 1) then
							-- Because we haven't seen this item before (according to the statistics) we should pad it to make the inaccuracy slightly less bad. 
							this_item_count = this_item_count + 1;
							break_chance_padded = true;
						end
					end
				end
			end
			if (this_break_count >= this_item_count) then
				-- Everything can break it... theoretically we should never get here...
				break_chance_text = '100.00%';
				break_chance_color = clamit.settings.weights.colors.high;
			elseif (this_break_count == 0) then
				-- Nothing can break it... theoretically we should never get here...
				break_chance_text = '0.00%';
				break_chance_color = clamit.settings.weights.colors.default;
			else
				-- Ok, now we really need to calculate the percentage.
				local this_chance = (this_break_count / this_item_count) * 100;
				break_chance_text = string.format("%.2f",this_chance) .. '%';
				if (this_chance >= 100) then
					-- Theoretically should never get here...
					break_chance_text = '100.00%';
					break_chance_color = clamit.settings.weights.colors.high;
				elseif (this_chance < 100 and this_chance >= 50) then
					break_chance_color = clamit.settings.weights.colors.high;
				elseif (this_chance < 50 and this_chance >= 30) then -- Tropical clam is ~1.5%, Jacknife is ~10%, Pebble is ~20% these are (somewhat) tuned for those thresholds.
					break_chance_color = clamit.settings.weights.colors.mid;
				elseif (this_chance < 30 and this_chance >= 10) then
					break_chance_color = clamit.settings.weights.colors.low;
				elseif (this_chance < 10 and this_chance >= 1) then
					break_chance_color = clamit.settings.weights.colors.super_low;
				else
					break_chance_color = clamit.settings.weights.colors.default;
				end
			end
		end
	end
	if (not clamit.settings.weights.enabled) then
		break_chance_color = clamit.settings.display.bucket_window.font_color;
	end
	-- Pre-calculate the bucket profit.
	local profit_text = 'N/A';
	local profit_color = clamit.settings.display.bucket_window.disabled_color;
	if (clamit.settings.bucket.active and not clamit.settings.bucket.broken) then
		local this_bucket_value = contents_value(clamit.settings.bucket.contents);
		if (clamit.settings.general.bucket.subtract_cost[1]) then
			this_bucket_value = this_bucket_value - clamit.settings.general.bucket.cost[1];
		end
		profit_text = format_int(this_bucket_value) .. 'g';
		if (this_bucket_value < 0) then
			profit_color = clamit.settings.values.bucket.colors.super_low;
		elseif (this_bucket_value >= 0 and this_bucket_value < clamit.settings.values.bucket.low[1]) then
			profit_color = clamit.settings.values.bucket.colors.default;
		elseif (this_bucket_value >= clamit.settings.values.bucket.low[1] and this_bucket_value < clamit.settings.values.bucket.mid[1]) then
			profit_color = clamit.settings.values.bucket.colors.low;
		elseif (this_bucket_value >= clamit.settings.values.bucket.mid[1] and this_bucket_value < clamit.settings.values.bucket.high[1]) then
			profit_color = clamit.settings.values.bucket.colors.mid;
		elseif (this_bucket_value >= clamit.settings.values.bucket.high[1]) then
			profit_color = clamit.settings.values.bucket.colors.high;
		end
	end
	if (not clamit.settings.values.bucket.enabled[1]) then
		profit_color = clamit.settings.display.bucket_window.font_color;
	end
	-- Pre-calculate the bucket contents.
	local bucket_contents = T {};
	local bucket_contents_count = 0;
	for i = 1, data.item_count do
		local this_item = data.sorting.alpha_asc[i];
		if (clamit.settings.bucket.contents[this_item] ~= nil) then
			bucket_contents_count = bucket_contents_count + 1;
			bucket_contents[bucket_contents_count] = T {};
			bucket_contents[bucket_contents_count].count = pad_to(clamit.settings.bucket.contents[this_item],2,true) .. 'x';
			bucket_contents[bucket_contents_count].count_color = clamit.settings.display.bucket_window.font_color;
			bucket_contents[bucket_contents_count].key = this_item;
			bucket_contents[bucket_contents_count].name = clamit.settings.item_list[this_item].name;
			bucket_contents[bucket_contents_count].name_color = clamit.settings.display.bucket_window.font_color;
			local this_value = 0;
			if (clamit.settings.item_list[this_item].use_ah[1] and clamit.settings.item_list[this_item].ah_value[1] > 0) then
				this_value = clamit.settings.item_list[this_item].ah_value[1];
			elseif (clamit.settings.general.bucket.vendor_value_low[1]) then
				this_value = clamit.settings.item_list[this_item].vendor_low[1];
			else
				this_value = clamit.settings.item_list[this_item].vendor_high[1];
			end
			bucket_contents[bucket_contents_count].value = '(' .. format_int(this_value * clamit.settings.bucket.contents[this_item]) .. 'g)';
			bucket_contents[bucket_contents_count].value_color = clamit.settings.display.bucket_window.font_color;
			if (clamit.settings.values.items.enabled[1]) then
				if (this_value >= clamit.settings.values.items.high[1]) then
					bucket_contents[bucket_contents_count].name_color = clamit.settings.values.items.colors.high;
				elseif (this_value >= clamit.settings.values.items.mid[1] and this_value < clamit.settings.values.items.high[1]) then
					bucket_contents[bucket_contents_count].name_color = clamit.settings.values.items.colors.mid;
				elseif (this_value >= clamit.settings.values.items.low[1] and this_value < clamit.settings.values.items.mid[1]) then
					bucket_contents[bucket_contents_count].name_color = clamit.settings.values.items.colors.low;
				elseif (this_value < clamit.settings.values.items.super_low[1]) then
					bucket_contents[bucket_contents_count].name_color = clamit.settings.values.items.colors.super_low;
				end
				this_value = this_value * clamit.settings.bucket.contents[this_item];
				if (this_value >= clamit.settings.values.items.high[1]) then
					bucket_contents[bucket_contents_count].value_color = clamit.settings.values.items.colors.high;
				elseif (this_value >= clamit.settings.values.items.mid[1] and this_value < clamit.settings.values.items.high[1]) then
					bucket_contents[bucket_contents_count].value_color = clamit.settings.values.items.colors.mid;
				elseif (this_value >= clamit.settings.values.items.low[1] and this_value < clamit.settings.values.items.mid[1]) then
					bucket_contents[bucket_contents_count].value_color = clamit.settings.values.items.colors.low;
				elseif (this_value < clamit.settings.values.items.super_low[1]) then
					bucket_contents[bucket_contents_count].value_color = clamit.settings.values.items.colors.super_low;
				end
			end
		end
	end
	-- Pre-calculate the session profits
	local session_profit_text = '0g';
	local session_profit_color = clamit.settings.display.bucket_window.font_color;
	if (clamit.settings.session.start_time ~= 0) then
		local this_value = contents_value(clamit.settings.session.gained);
		if (clamit.settings.general.bucket.subtract_cost[1] and clamit.settings.session.buckets.total > 0) then
			this_value = this_value - (clamit.settings.session.buckets.total * clamit.settings.general.bucket.cost[1]);
		end
		session_profit_text = format_int(this_value) .. 'g';
		if (clamit.settings.values.session.enabled[1]) then
			if (this_value >= clamit.settings.values.session.high[1]) then
				session_profit_color = clamit.settings.values.session.colors.high;
			elseif (this_value >= clamit.settings.values.session.mid[1] and this_value < clamit.settings.values.session.high[1]) then
				session_profit_color = clamit.settings.values.session.colors.mid;
			elseif (this_value >= clamit.settings.values.session.low[1] and this_value < clamit.settings.values.session.mid[1]) then
				session_profit_color = clamit.settings.values.session.colors.low;
			elseif (this_value < clamit.settings.values.session.super_low[1]) then
				session_profit_color = clamit.settings.values.session.colors.super_low;
			else
				session_profit_color = clamit.settings.values.session.colors.default;
			end
		end
	end
	

	-- Render the layout.
	imgui.SetNextWindowBgAlpha(clamit.settings.display.bucket_window.opacity[1]);
	imgui.SetNextWindowSize({-1, -1}, ImGuiCond_Always);
	if (imgui.Begin('Clamit##Bucket', clamit.settings.display.bucket_window.visible[1], bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav))) then
		-- Stuff that might be used in a few places...
		local weight_diff = clamit.settings.bucket.capacity - clamit.settings.bucket.weight;
		-- Main Header for the Bucket display.
		imgui.SeparatorText('Clamming Bucket');
		if (imgui.BeginTable("##BucketHeader", 2, bit.bor(ImGuiTableFlags_None))) then
			imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthFixed, icon_full_size);
			imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthStretch, 1.0);
			imgui.TableNextRow();
			imgui.TableNextColumn();
			if (imgui.BeginTable("##BucketHeaderIcons", 1, bit.bor(ImGuiTableFlags_SizingFixedFit), 0.0, 0.0)) then
				imgui.TableNextRow();
				imgui.TableNextColumn();
				if (top_icon.Pointer ~= nil) then imgui.Image(top_icon.Pointer, { icon_full_size, icon_full_size }); end
				imgui.TableNextRow();
				imgui.TableNextColumn();
				if (bottom_icon.Pointer ~= nil) then imgui.Image(bottom_icon.Pointer, { icon_full_size, icon_full_size }); end
				imgui.EndTable();
			end
			imgui.TableNextColumn();
			if (imgui.BeginTable("##BucketHeaderStatus", 2, bit.bor(ImGuiTableFlags_SizingFixedFit), 0.0, 0.0)) then
				imgui.TableNextRow();
				imgui.TableNextColumn();
				imgui.Text('Bucket Status:');
				imgui.TableNextColumn();
				imgui.TextColored(status_color,status_text);
				imgui.TableNextRow();
				imgui.TableNextColumn();
				imgui.Text('Bucket Weight:');
				imgui.TableNextColumn();
				imgui.TextColored(weight_color,weight_text);
				imgui.TableNextRow();
				imgui.TableNextColumn();
				imgui.Text('    Dig Timer:');
				imgui.TableNextColumn();
				if (clamit.tracking.dig_timer == 0) then
					imgui.TextColored(clamit.settings.dig_timer.color,"Ready!");
				else
					imgui.TextColored(clamit.settings.dig_timer.color,clamit.settings.dig_timer.count);
				end
				imgui.TableNextRow();
				imgui.TableNextColumn();
				imgui.Text(' Break Chance:');
				imgui.TableNextColumn();
				imgui.TextColored(break_chance_color,break_chance_text);
				if (break_chance_padded) then
					imgui.SameLine();
					imgui.ShowHelp('This calculation has been adjusted due to lack of data, reducing overall accuracy. Once you\'ve seen at least 1 of every item it won\'t need adjusting anymore.');
				end
				imgui.TableNextRow();
				imgui.TableNextColumn();
				if (clamit.settings.general.bucket.subtract_cost) then
					imgui.Text("Bucket Profit:");
				else
					imgui.Text(" Bucket Value:");
				end
				imgui.TableNextColumn();
				imgui.TextColored(profit_color,profit_text);
				imgui.EndTable();
			end
			imgui.EndTable();
		end
		-- Bucket Contents
		if (clamit.settings.bucket.active) then
			imgui.SeparatorText('Contents');
			if (clamit.settings.bucket.items.total > 0) then
				imgui.PushStyleVar(ImGuiStyleVar_CellPadding, {2.0, 1.0});
				if (imgui.BeginTable("##BucketContents", 3, bit.bor(ImGuiTableFlags_SizingFixedFit), 0.0, 0.0)) then
					for i = 1, bucket_contents_count do
						if (bucket_contents[i] ~= nil and bucket_contents[i] ~= {}) then
							imgui.TableNextRow();
							imgui.TableNextColumn();
							imgui.TextColored(bucket_contents[i].count_color,bucket_contents[i].count);
							imgui.TableNextColumn();
							if (clamit.item_icons[bucket_contents[i].key].Pointer ~= nil) then imgui.Image(clamit.item_icons[bucket_contents[i].key].Pointer, { icon_small_size, icon_small_size }); end
							imgui.TableNextColumn();
							imgui.TextColored(bucket_contents[i].name_color,bucket_contents[i].name);
							imgui.SameLine();
							imgui.TextColored(bucket_contents[i].value_color,bucket_contents[i].value);
						end
					end
					imgui.EndTable();
				end
				imgui.PopStyleVar(1);
			end
			imgui.Text("Item Count: " .. clamit.settings.bucket.items.total .. '(' .. clamit.settings.bucket.items.unique .. ')');
		end
		-- Session Info
		if (clamit.settings.session.start_time ~= 0) then
			imgui.SeparatorText('Session - ' .. time_since(clamit.settings.session.start_time));
			if (clamit.settings.general.session_stats[1]) then
				if (imgui.BeginTable("##BucketSessionTop", 5, bit.bor(ImGuiTableFlags_SizingFixedFit), 0.0, 0.0)) then
					imgui.TableNextRow();
					imgui.TableNextColumn();
					imgui.Text(' Items:');
					imgui.TableNextColumn();
					imgui.TableNextColumn();
					imgui.Text(' ');
					imgui.TableNextColumn();
					imgui.Text(' Buckets:');
					imgui.TableNextColumn();
					imgui.TableNextRow();
					imgui.TableNextColumn();
					imgui.Text('   Dug:');
					imgui.TableNextColumn();
					imgui.Text(clamit.settings.session.items.total);
					imgui.TableNextColumn();
					imgui.TableNextColumn();
					imgui.Text('   Total:');
					imgui.TableNextColumn();
					imgui.Text(clamit.settings.session.buckets.total);
					imgui.TableNextRow();
					imgui.TableNextColumn();
					imgui.Text('  Lost:');
					imgui.TableNextColumn();
					imgui.Text(clamit.settings.session.items.lost);
					imgui.TableNextColumn();
					imgui.TableNextColumn();
					imgui.Text('  Breaks:');
					imgui.TableNextColumn();
					imgui.Text(clamit.settings.session.buckets.breaks);
					imgui.TableNextRow();
					imgui.TableNextColumn();
					imgui.Text('Gained:');
					imgui.TableNextColumn();
					imgui.Text(clamit.settings.session.items.gained);
					imgui.TableNextColumn();
					imgui.TableNextColumn();
					imgui.Text('Upgrades:');
					imgui.TableNextColumn();
					imgui.Text(clamit.settings.session.buckets.upgrades);
					imgui.EndTable();
				end
			end

			if (imgui.BeginTable("##BucketSessionValueContainer", 2, bit.bor(ImGuiTableFlags_None))) then
				imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthFixed, icon_full_size);
				imgui.TableSetupColumn('', ImGuiTableColumnFlags_WidthStretch, 1.0);
				imgui.TableNextRow();
				imgui.TableNextColumn();
				imgui.PushStyleVar(ImGuiStyleVar_CellPadding, {2.0, 0.0});
				if (imgui.BeginTable("##BucketSessionIcon", 1, bit.bor(ImGuiTableFlags_SizingFixedFit), 0.0, 0.0)) then
					imgui.TableNextRow();
					imgui.TableNextColumn();
					imgui.Text();
					imgui.TableNextRow();
					imgui.TableNextColumn();
					if (clamit.gil_icon.Pointer ~= nil) then imgui.Image(clamit.gil_icon.Pointer, { icon_full_size, icon_full_size }); end
					imgui.EndTable();
				end
				imgui.PopStyleVar(1);
				imgui.TableNextColumn();
				if (imgui.BeginTable("##BucketSessionValues", 2, bit.bor(ImGuiTableFlags_SizingFixedFit), 0.0, 0.0)) then
					local this_lost = 0;
					if (clamit.settings.session.items.lost > 0) then
						this_lost = contents_value(clamit.settings.session.lost);
					end
					imgui.TableNextRow();
					imgui.TableNextColumn();
					imgui.Text("Buckets Cost:");
					imgui.TableNextColumn();
					imgui.Text(format_int(clamit.settings.session.buckets.total * clamit.settings.general.bucket.cost[1]) .. 'g');
					imgui.TableNextRow();
					imgui.TableNextColumn();
					imgui.Text('  Lost Value:');
					imgui.TableNextColumn();
					imgui.Text(format_int(this_lost) .. 'g');
					imgui.TableNextRow();
					imgui.TableNextColumn();
					imgui.Text('Gil Per Hour:');
					imgui.TableNextColumn();
					imgui.Text(format_int(clamit.tracking.gil_per_hour) .. 'g');
					imgui.TableNextRow();
					imgui.TableNextColumn();
					if (clamit.settings.general.bucket.subtract_cost[1]) then
						imgui.Text('Total Profit:');
					else
						imgui.Text(' Total Value:');
					end
					imgui.TableNextColumn();
					imgui.TextColored(session_profit_color,session_profit_text);
					imgui.EndTable();
				end
				imgui.EndTable();
			end
		end
	end
	imgui.End();
end

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'd3d_present_callback1', function ()
	-- Don't show anything if ashita is hiding things...
	if (not AshitaCore:GetFontManager():GetVisible()) then return; end
	local start_time = ashita.time.clock()['ms'];
	-- Check / update the dig timer
	if (clamit.tracking.dig_timer ~= 0) then
		local seconds_since_dig = math.floor((start_time - clamit.tracking.dig_timer)/1000);
		if (seconds_since_dig >= clamit.settings.dig_timer.interval) then -- The timer has finished. Should be if it's 10+
			clamit.tracking.dig_timer = 0; -- Reset this so we don't keep trying to run this timer loop.
			if (clamit.settings.dig_timer.countdown[1]) then -- Probably unnecessary, but maintians clarity if we screw something up in the display.
				clamit.settings.dig_timer.count = 0;
			else
				clamit.settings.dig_timer.count = clamit.settings.dig_timer.interval;
			end
			play_sound(clamit.settings.sounders.dig_ready);
		else
			if (clamit.settings.dig_timer.countdown[1]) then -- The timer display should count down
				clamit.settings.dig_timer.count = clamit.settings.dig_timer.interval - seconds_since_dig;
			else -- The timer display should count up (But why...?)
				clamit.settings.dig_timer.count = seconds_since_dig;
			end
		end
	end
	-- Check if the Character changed...
	local current_character = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0);
	if (current_character ~= clamit.current_character_name) then
		-- In theory, settings should automatically switch over... but it doesn't always work out that way, so lets clear the bucket & session, and load the settings...
		local prev_character = clamit.current_character_name;
		--clear_bucket();
		--clear_session();
		--settings.load();		
		load_character(); -- Do the same stuff we would at load time...
		add_message("Character change: " .. prev_character .. ' > ' .. clamit.current_character_name .. '.',true);
	end
	-- Check our location - we might need to update the bucket because zoning screws the bucket.
	local current_area = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0); -- Find the current area.
	if (current_area ~= 4) then
		-- We're not in Bibiki Bay, check if we need to flush the bucket...
		if (clamit.settings.bucket.active and not clamit.settings.bucket.zoned) then
			-- We have an active bucket that isn't already marked as having zoned
			add_message("Active bucket outside of Bibiki Bay, flushing items...",false);
			-- Flush the items - but leave the weight alone, that stays.
			clamit.settings.bucket.zoned = true;
			clamit.settings.bucket.items.total = 0;
			clamit.settings.bucket.items.unique = 0;
			clamit.settings.bucket.contents = T {};
			-- Save the settings. (So we don't keep giving the flush message more than anything...)
			settings.save();
		elseif (clamit.settings.bucket.active and clamit.settings.bucket.zoned) then
			-- We have a flushed bucket, but we'll check for new items...
			if (clamit.settings.bucket.items.total > 0) then
				add_message("Active bucket outside of Bibiki Bay, flushing items...",false);
				-- Flush the items - but leave the weight alone, that stays.
				clamit.settings.bucket.zoned = true;
				clamit.settings.bucket.items.total = 0;
				clamit.settings.bucket.items.unique = 0;
				clamit.settings.bucket.contents = T {};
				-- Save the settings. (So we don't keep giving the flush message more than anything...)
				settings.save();
			end
		end
	end
	if (clamit.tracking.current_area ~= current_area) then
		-- Area changed - Probably not going to do anything with this...
		clamit.tracking.last_area = clamit.tracking.current_area;
		clamit.tracking.current_area = current_area;
	end
	-- Check if we have to send messages to chat (Things that text_in generated that we can't safely call from within that hook).
	if (clamit.pending_message) then
		-- Print the messages
		for _, v in pairs(clamit.pending_messages) do
			print(chat.header(addon.name):append(v));
		end
		-- Clear the messages now they've been printed.
		clamit.pending_message = false;
		clamit.pending_messages = T {};
	end
	-- Check if we need to display the tracking / bucket window
	if (current_area ~= 4 and not clamit.settings.general.out_of_area[1] and not clamit.tracking.show_override) then -- Should we be hiding this due to being out of area?
		clamit.settings.display.bucket_window.visible[1] = clamit.settings.display.config_window.visible[1]; -- Since we actually want to show it if the config is open, we can simply do this...
	else
		local seconds_since_action = math.floor((start_time - clamit.tracking.last_action)/1000);
		if (clamit.settings.display.config_window.visible[1] or (seconds_since_action <= clamit.settings.display.bucket_window.timeout[1])) then
			clamit.settings.display.bucket_window.visible[1] = true;
		else
			clamit.settings.display.bucket_window.visible[1] = false;
			if (clamit.tracking.show_override) then
				-- We might want to clear the override... we'll leave it for now tho.
				--clamit.tracking.show_override = false;
			end
		end
	end
	-- Update gil_per_hour if we need to
	if (clamit.settings.session.start_time ~= 0) then
		local session_seconds = math.floor((start_time - clamit.settings.session.start_time) / 1000);
		local current_value = contents_value(clamit.settings.session.gained);
		if (clamit.settings.general.bucket.subtract_cost[1]) then
			current_value = current_value - (clamit.settings.session.buckets.total * clamit.settings.general.bucket.cost[1]);
		end
		if (session_seconds < 3600 and current_value < 1) then
			-- It's been less than an hour and value is 0 or less, so let's just set it to the current value (probably 0 or -500) for now, instead of the silly -1000000+ that can come up early on...
			clamit.tracking.gil_per_hour = current_value;
		else -- It's been more than an hour, or the value is greater than 0, so lets do the calculations
			clamit.tracking.gil_per_hour = math.floor(current_value / (session_seconds / 3600));
		end
	else
		clamit.tracking.gil_per_hour = 0;
	end
	-- Call the render functions
	render_config();
	render_bucket();
end);
