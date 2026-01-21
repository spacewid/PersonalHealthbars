return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`PersonalHealthbars` encountered an error loading the Darktide Mod Framework.")

		new_mod("PersonalHealthbars", {
			mod_script       = "PersonalHealthbars/scripts/mods/PersonalHealthbars/PersonalHealthbars",
			mod_data         = "PersonalHealthbars/scripts/mods/PersonalHealthbars/PersonalHealthbars_data",
			mod_localization = "PersonalHealthbars/scripts/mods/PersonalHealthbars/PersonalHealthbars_localization",
		})
	end,
	packages = {},
}



