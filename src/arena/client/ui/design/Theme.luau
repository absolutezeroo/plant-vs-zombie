--!strict
--[[
	Theme.luau
	"Toon Pop" Design System - Cartoon, Solid, Tactile
	
	Central source of truth for all UI styling constants.
]]

export type ColorSet = {
	Main: Color3,
	Shadow: Color3,
	Text: Color3?,
	Stroke: Color3?,
}

export type ColorsType = {
	Surface: ColorSet,
	Action: ColorSet,
	Danger: ColorSet,
	Info: ColorSet,
}

export type TypographyType = {
	Fonts: {
		Title: Enum.Font,
		Body: Enum.Font,
	},
}

export type LayoutType = {
	CornerRadius: UDim,
	StrokeThickness: number,
	ButtonHeight: number,
}

export type ThemeType = {
	Colors: ColorsType,
	Typography: TypographyType,
	Layout: LayoutType,
}

local Theme: ThemeType = {
	Colors = {
		-- Panels, cards, backgrounds
		Surface = {
			Main = Color3.fromHex("#F5E6C4"),    -- Beige
			Shadow = Color3.fromHex("#C4B28A"),  -- Brown
			Stroke = Color3.fromHex("#5D4037"),  -- DarkBrown
		},

		-- Primary action buttons (confirm, plant, etc.)
		Action = {
			Main = Color3.fromHex("#76C655"),    -- Green
			Shadow = Color3.fromHex("#4E8F35"),  -- DarkGreen
			Text = Color3.fromHex("#FFFFFF"),    -- White
		},

		-- Destructive actions (cancel, remove, etc.)
		Danger = {
			Main = Color3.fromHex("#E74C3C"),    -- Red
			Shadow = Color3.fromHex("#C0392B"),  -- DarkRed
			Text = Color3.fromHex("#FFFFFF"),    -- White
		},

		-- Informational elements (tooltips, hints, etc.)
		Info = {
			Main = Color3.fromHex("#3498DB"),    -- Blue
			Shadow = Color3.fromHex("#2980B9"),  -- DarkBlue
			Text = Color3.fromHex("#FFFFFF"),    -- White
		},
	},

	Typography = {
		Fonts = {
			Title = Enum.Font.LuckiestGuy,  -- Bold cartoon headers
			Body = Enum.Font.GothamBold,    -- Readable body text
		},
	},

	Layout = {
		CornerRadius = UDim.new(0, 12),  -- Rounded cartoon corners
		StrokeThickness = 3,              -- Thick cartoon outlines
		ButtonHeight = 50,                -- Touch-friendly button size
	},
}

return table.freeze(Theme) :: ThemeType
