local stack = setmetatable({}, {
	__index = {
		front = function(self)
			return self[#self]
		end,
		pop_front = function(self)
			table.remove(self)
		end,
		push_front = function(self, modal)
			table.insert(self, modal)
		end,
	},
})

local hide_timer = mp.add_timeout(
	mp.get_property_number('osd-duration') / 1000,
	function()
		stack:front():hide()
	end,
	true
)

local Modal = {}
Modal.__index = Modal

function Modal:is_visible()
	return stack:front() == self
end

function Modal:show()
	local front = stack:front()

	if front == self then
		hide_timer:kill()
		return
	end

	if hide_timer:is_enabled() then
		hide_timer:kill()
		stack:pop_front()
	end

	stack:push_front(self)

	self.update()

	if front then
		front.update()
	end
end

function Modal:hide()
	local front = stack:front()

	if front ~= self then
		return
	end

	hide_timer:kill()
	stack:pop_front()
	front = stack:front()

	self.update()

	if front then
		front.update()
	end
end

local function new_modal(update)
	local modal = setmetatable({ update = update }, Modal)

	function modal.set_visibility(action)
		if action == 'show' then
			modal:show()
		elseif action == 'hide' then
			modal:hide()
		elseif action == 'toggle' then
			if modal:is_visible() then
				modal:hide()
			else
				modal:show()
			end
		elseif action == 'peek' then
			if not modal:is_visible() then
				modal:show()
				hide_timer:resume()
			elseif hide_timer:is_enabled() then
				hide_timer:kill()
				hide_timer:resume()
			end
		else
			mp.msg.error(
				('Invalid visibility %s, expected one of: show, hide, toggle, peek.'):format(
					action
				)
			)
			return
		end
	end

	return modal
end

return { new = new_modal }
