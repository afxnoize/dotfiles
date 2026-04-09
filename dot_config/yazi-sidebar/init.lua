-- Vertical layout: current (top) + preview (bottom)
-- Hide preview when height is too small
local PREVIEW_MIN_HEIGHT = 20

function Tab:layout()
	if self._area.h < PREVIEW_MIN_HEIGHT then
		self._chunks = { self._area }
	else
		self._chunks = ui.Layout()
			:direction(ui.Layout.VERTICAL)
			:constraints({
				ui.Constraint.Fill(2),
				ui.Constraint.Fill(1),
			})
			:split(self._area)
	end
end

function Tab:build()
	local c = self._chunks
	if #c == 1 then
		self._children = {
			Current:new(c[1], self._tab),
		}
	else
		self._children = {
			Current:new(c[1], self._tab),
			Preview:new(c[2], self._tab),
		}
	end
end
