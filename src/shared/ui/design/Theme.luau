--!strict
--[[
	Theme.luau
	"Toon Pop" Design System - Cartoon, Solid, Tactile
	
	Central source of truth for all UI styling constants.
	SHARED between Arena and Lobby.
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
	Warning: ColorSet,
	Gold: ColorSet,
	Purple: ColorSet,
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
	CardPadding: number,
	SectionSpacing: number,
	OverlaySize: UDim2,
	OverlayPosition: UDim2,
	OverlayAnchorPoint: Vector2,
}

export type IconsType = {
	Coin: string,
	Gem: string,
	XP: string,
	Sun: string,
	Star: string,
	StarEmpty: string,
	Lock: string,
	Check: string,
	Close: string,
	Back: string,
	Play: string,
	Shop: string,
	Deck: string,
	Profile: string,
	Mutation: string,
}

export type ThemeType = {
	Colors: ColorsType,
	Typography: TypographyType,
	Layout: LayoutType,
	Icons: IconsType,
}

local Theme: ThemeType = {
	Colors = {
		-- Panels, cards, backgrounds
		Surface = {
			Main = Color3.fromHex("#F5E6C4"), -- Beige
			Shadow = Color3.fromHex("#C4B28A"), -- Brown
			Stroke = Color3.fromHex("#5D4037"), -- DarkBrown
		},

		-- Primary action buttons (confirm, plant, play)
		Action = {
			Main = Color3.fromHex("#76C655"), -- Green
			Shadow = Color3.fromHex("#4E8F35"), -- DarkGreen
			Text = Color3.fromHex("#FFFFFF"), -- White
		},

		-- Destructive actions (cancel, remove)
		Danger = {
			Main = Color3.fromHex("#E74C3C"), -- Red
			Shadow = Color3.fromHex("#C0392B"), -- DarkRed
			Text = Color3.fromHex("#FFFFFF"), -- White
		},

		-- Informational elements (tooltips, hints)
		Info = {
			Main = Color3.fromHex("#3498DB"), -- Blue
			Shadow = Color3.fromHex("#2980B9"), -- DarkBlue
			Text = Color3.fromHex("#FFFFFF"), -- White
		},

		-- Warnings, attention
		Warning = {
			Main = Color3.fromHex("#F39C12"), -- Orange
			Shadow = Color3.fromHex("#D68910"), -- DarkOrange
			Text = Color3.fromHex("#FFFFFF"), -- White
		},

		-- Currency, rewards (coins)
		Gold = {
			Main = Color3.fromHex("#FFD700"), -- Gold
			Shadow = Color3.fromHex("#B8860B"), -- DarkGold
			Text = Color3.fromHex("#5D4037"), -- Brown
		},

		-- Premium currency (gems)
		Purple = {
			Main = Color3.fromHex("#9B59B6"), -- Purple
			Shadow = Color3.fromHex("#7D3C98"), -- DarkPurple
			Text = Color3.fromHex("#FFFFFF"), -- White
		},
	},

	Typography = {
		Fonts = {
			Title = Enum.Font.LuckiestGuy, -- Bold cartoon headers
			Body = Enum.Font.GothamBold, -- Readable body text
		},
	},

	Layout = {
		CornerRadius = UDim.new(0, 12), -- Rounded cartoon corners
		StrokeThickness = 3, -- Thick cartoon outlines
		ButtonHeight = 50, -- Touch-friendly button size
		CardPadding = 16, -- Internal card padding
		SectionSpacing = 24, -- Spacing between sections
		-- Overlay screens (Shop, DeckBuilder, MutationLab, etc.)
		OverlaySize = UDim2.fromScale(0.92, 0.92),
		OverlayPosition = UDim2.fromScale(0.5, 0.5),
		OverlayAnchorPoint = Vector2.new(0.5, 0.5),
	},

	Icons = {
		Coin = "💸",
		Gem = "💎",
		XP = "⭐",
		Sun = "☀️",
		Star = "⭐",
		StarEmpty = "☆",
		Lock = "🔒",
		Check = "✓",
		Close = "✖️",
		Back = "←",
		Play = "▶",
		Shop = "🛒",
		Deck = "🃏",
		Profile = "👤",
		Mutation = "🧬",
	},
}

return table.freeze(Theme) :: ThemeType
