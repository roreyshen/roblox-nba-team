-- A small mock of the Roblox engine so the real server + client scripts can run in the Luau CLI.
-- Every property set, method call, event and enum is checked against the real Roblox API dump,
-- remotes copy their arguments with Roblox's rules, and signals fire deferred (Roblox default).

local G = require("./generated")
local API, ENUMS, FONTS, TREE = G.API, G.ENUMS, G.FONTS, G.TREE

local M = {}
M.errors = {} :: { string }
M.warnings = {} :: { string }
M.prints = false

local function fail(msg: string)
	table.insert(M.errors, msg)
end
M.fail = fail

---------------------------------------------------------------- scheduler

local now = 0
local queue = {}
local seq = 0
local currentVM: any = nil
local cancelled = setmetatable({}, { __mode = "k" })

local function resume(co: thread, vm: any, ...)
	if vm and vm.dead then
		return
	end
	local prev = currentVM
	currentVM = vm
	local ok, err = coroutine.resume(co, ...)
	currentVM = prev
	if not ok then
		fail(("[%s] %s\n%s"):format(if vm then vm.name else "?", tostring(err), debug.traceback(co)))
	end
end

local function schedule(t: number, co: thread, vm: any, ...)
	seq += 1
	table.insert(queue, { t = t, seq = seq, co = co, vm = vm, args = table.pack(...) })
end

local taskLib = {}
function taskLib.spawn(f: any, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	resume(co, currentVM, ...)
	return co
end
function taskLib.defer(f: any, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	schedule(now, co, currentVM, ...)
	return co
end
function taskLib.delay(t: number?, f: any, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	schedule(now + (t or 0), co, currentVM, ...)
	return co
end
function taskLib.wait(t: number?)
	local co = coroutine.running()
	local start = now
	schedule(now + math.max(t or 0, 1 / 60), co, currentVM)
	coroutine.yield()
	return now - start
end
function taskLib.cancel(co: thread)
	cancelled[co] = true
end

function M.now(): number
	return now
end

local frameSignals: { any } = {}

function M.run(seconds: number)
	local target = now + seconds
	local nextFrame = math.floor(now * 30 + 1) / 30
	while true do
		local bestI = nil
		local best = nil
		for i, item in queue do
			if item.t <= target and (best == nil or item.t < best.t or (item.t == best.t and item.seq < best.seq)) then
				bestI, best = i, item
			end
		end
		if best and best.t <= nextFrame then
			table.remove(queue, bestI)
			if best.t > now then
				now = best.t
			end
			if not cancelled[best.co] and coroutine.status(best.co) == "suspended" then
				resume(best.co, best.vm, table.unpack(best.args, 1, best.args.n))
			end
		elseif nextFrame <= target then
			now = nextFrame
			for _, sig in frameSignals do
				sig:Fire(1 / 30)
			end
			nextFrame += 1 / 30
		else
			break
		end
	end
	now = target
end

---------------------------------------------------------------- datatypes

local function datatype(typeName: string, fields: { [string]: any }, mt: { [string]: any }?)
	local meta = mt or {}
	meta.__type = typeName
	meta.__index = meta.__index or function(_, k)
		error(("%s is not a valid member of %s"):format(tostring(k), typeName), 2)
	end
	meta.__newindex = function(_, k)
		error(("%s.%s is read-only"):format(typeName, tostring(k)), 2)
	end
	meta.__tostring = meta.__tostring or function()
		return typeName
	end
	return setmetatable(fields, meta)
end

local InstanceMT = {}

local function typeOf(v: any): string
	local t = type(v)
	if t == "table" then
		if getmetatable(v) == InstanceMT then
			return "Instance"
		end
		local mt = getmetatable(v)
		if type(mt) == "table" and rawget(mt, "__type") then
			return mt.__type
		end
	end
	return typeof(v)
end
M.typeOf = typeOf

local function num(v: any, what: string): number
	if type(v) ~= "number" then
		error(what .. " expects a number, got " .. typeOf(v), 3)
	end
	return v
end

local Color3 = {}
local Color3MT = {}
Color3MT.__index = function(self, k)
	if k == "Lerp" then
		return function(a, b, alpha)
			return Color3.new(a.R + (b.R - a.R) * alpha, a.G + (b.G - a.G) * alpha, a.B + (b.B - a.B) * alpha)
		end
	elseif k == "ToHex" or k == "ToHSV" then
		return function()
			return "000000"
		end
	end
	error(tostring(k) .. " is not a valid member of Color3", 2)
end
Color3MT.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
function Color3.new(r: number?, g: number?, b: number?)
	return datatype("Color3", { R = r or 0, G = g or 0, B = b or 0 }, table.clone(Color3MT))
end
function Color3.fromRGB(r: number?, g: number?, b: number?)
	return Color3.new(num(r or 0, "Color3.fromRGB") / 255, num(g or 0, "Color3.fromRGB") / 255, num(b or 0, "Color3.fromRGB") / 255)
end
function Color3.fromHex(hex: string)
	assert(type(hex) == "string")
	return Color3.new(0, 0, 0)
end

local UDim = {}
function UDim.new(scale: number?, offset: number?)
	return datatype("UDim", { Scale = num(scale or 0, "UDim.new"), Offset = num(offset or 0, "UDim.new") })
end

local UDim2 = {}
local UDim2MT = {}
function UDim2.new(xs: number?, xo: number?, ys: number?, yo: number?)
	if typeOf(xs) == "UDim" then
		local x, y = xs :: any, xo :: any
		return UDim2.new(x.Scale, x.Offset, y.Scale, y.Offset)
	end
	local x = UDim.new(num(xs or 0, "UDim2.new"), num(xo or 0, "UDim2.new"))
	local y = UDim.new(num(ys or 0, "UDim2.new"), num(yo or 0, "UDim2.new"))
	return datatype("UDim2", { X = x, Y = y, Width = x, Height = y }, table.clone(UDim2MT))
end
UDim2MT.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UDim2MT.__sub = function(a, b)
	return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
function UDim2.fromScale(x: number?, y: number?)
	return UDim2.new(x or 0, 0, y or 0, 0)
end
function UDim2.fromOffset(x: number?, y: number?)
	return UDim2.new(0, x or 0, 0, y or 0)
end

local Vector2 = {}
local V2MT = {}
function Vector2.new(x: number?, y: number?)
	return datatype("Vector2", { X = num(x or 0, "Vector2.new"), Y = num(y or 0, "Vector2.new") }, table.clone(V2MT))
end
V2MT.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
V2MT.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
V2MT.__mul = function(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X * b, a.Y * b)
	end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)

local Vector3 = {}
local V3MT = {}
function Vector3.new(x: number?, y: number?, z: number?)
	return datatype(
		"Vector3",
		{ X = num(x or 0, "Vector3.new"), Y = num(y or 0, "Vector3.new"), Z = num(z or 0, "Vector3.new") },
		table.clone(V3MT)
	)
end
V3MT.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3MT.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3MT.__mul = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	elseif type(a) == "number" then
		return Vector3.new(b.X * a, b.Y * a, b.Z * a)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.zero = Vector3.new(0, 0, 0)

local CFrame = {}
local CFMT = {}
function CFrame.new(x: any?, y: number?, z: number?)
	local pos
	if typeOf(x) == "Vector3" then
		pos = x
	else
		pos = Vector3.new(x or 0, y or 0, z or 0)
	end
	return datatype("CFrame", { Position = pos, X = pos.X, Y = pos.Y, Z = pos.Z }, table.clone(CFMT))
end
CFMT.__mul = function(a, b)
	if typeOf(b) == "CFrame" then
		return CFrame.new(a.Position + b.Position)
	elseif typeOf(b) == "Vector3" then
		return a.Position + b
	end
	error("bad CFrame multiplication with " .. typeOf(b), 2)
end
function CFrame.Angles(rx: number, ry: number, rz: number)
	num(rx, "CFrame.Angles")
	num(ry, "CFrame.Angles")
	num(rz, "CFrame.Angles")
	return CFrame.new(0, 0, 0)
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles

local function checkKeypoints(kps: { any }, kind: string)
	if #kps < 2 then
		error(kind .. " needs at least 2 keypoints", 3)
	end
	if kps[1].Time ~= 0 or kps[#kps].Time ~= 1 then
		error(kind .. " keypoints must start at time 0 and end at time 1", 3)
	end
	for i = 2, #kps do
		if kps[i].Time < kps[i - 1].Time then
			error(kind .. " keypoints must be in time order", 3)
		end
	end
end

local ColorSequenceKeypoint = {}
function ColorSequenceKeypoint.new(t: number, c: any)
	num(t, "ColorSequenceKeypoint.new")
	assert(typeOf(c) == "Color3", "ColorSequenceKeypoint.new expects a Color3")
	return datatype("ColorSequenceKeypoint", { Time = t, Value = c })
end
local ColorSequence = {}
function ColorSequence.new(a: any, b: any?)
	local kps
	if typeOf(a) == "Color3" then
		if b ~= nil and typeOf(b) ~= "Color3" then
			error("ColorSequence.new expects Color3 values", 2)
		end
		kps = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) }
	elseif type(a) == "table" then
		kps = a
		for _, k in kps do
			if typeOf(k) ~= "ColorSequenceKeypoint" then
				error("ColorSequence.new expects ColorSequenceKeypoints", 2)
			end
		end
	else
		error("ColorSequence.new: bad argument " .. typeOf(a), 2)
	end
	checkKeypoints(kps, "ColorSequence")
	return datatype("ColorSequence", { Keypoints = kps })
end

local NumberSequenceKeypoint = {}
function NumberSequenceKeypoint.new(t: number, v: number, e: number?)
	return datatype("NumberSequenceKeypoint", { Time = num(t, "NumberSequenceKeypoint.new"), Value = num(v, "NumberSequenceKeypoint.new"), Envelope = e or 0 })
end
local NumberSequence = {}
function NumberSequence.new(a: any, b: any?)
	local kps
	if type(a) == "number" then
		kps = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) }
	elseif type(a) == "table" then
		kps = a
		for _, k in kps do
			if typeOf(k) ~= "NumberSequenceKeypoint" then
				error("NumberSequence.new expects NumberSequenceKeypoints", 2)
			end
		end
	else
		error("NumberSequence.new: bad argument", 2)
	end
	checkKeypoints(kps, "NumberSequence")
	return datatype("NumberSequence", { Keypoints = kps })
end

local NumberRange = {}
function NumberRange.new(a: number, b: number?)
	return datatype("NumberRange", { Min = a, Max = b or a })
end

---------------------------------------------------------------- enums

local EnumItems: { [string]: { [string]: any } } = {}
local EnumTypes: { [string]: any } = {}
for enumName, items in ENUMS do
	local byName = {}
	local enumType = datatype("Enum", {}, {
		__index = function(_, k)
			local item = byName[k]
			if item then
				return item
			end
			if k == "GetEnumItems" then
				return function()
					local out = {}
					for _, it in byName do
						table.insert(out, it)
					end
					return out
				end
			end
			error(("%s is not a valid member of \"Enum.%s\""):format(tostring(k), enumName), 2)
		end,
		__tostring = function()
			return enumName
		end,
	})
	for itemName, value in items do
		byName[itemName] = datatype("EnumItem", { Name = itemName, Value = value, EnumType = enumType }, {
			__tostring = function()
				return "Enum." .. enumName .. "." .. itemName
			end,
		})
	end
	EnumItems[enumName] = byName
	EnumTypes[enumName] = enumType
end
local Enum = datatype("Enums", {}, {
	__index = function(_, k)
		local e = EnumTypes[k]
		if not e then
			error(tostring(k) .. " is not a valid EnumItem", 2)
		end
		return e
	end,
})

local function enumTypeName(item: any): string?
	if typeOf(item) ~= "EnumItem" then
		return nil
	end
	return tostring(item.EnumType)
end

local TweenInfo = {}
function TweenInfo.new(time: number?, style: any?, direction: any?, repeatCount: number?, reverses: boolean?, delay: number?)
	if style ~= nil and enumTypeName(style) ~= "EasingStyle" then
		error("TweenInfo.new: argument 2 must be an EasingStyle", 2)
	end
	if direction ~= nil and enumTypeName(direction) ~= "EasingDirection" then
		error("TweenInfo.new: argument 3 must be an EasingDirection", 2)
	end
	return datatype("TweenInfo", {
		Time = time or 1,
		EasingStyle = style,
		EasingDirection = direction,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delay or 0,
	})
end

local Font = {}
function Font.new(family: string, weight: any?, style: any?)
	if type(family) ~= "string" then
		error("Font.new: family must be a string", 2)
	end
	local name = family:match("^rbxasset://fonts/families/([%w]+)%.json$")
	if not name or not FONTS[name] then
		error("Font.new: unknown font family " .. family, 2)
	end
	if weight ~= nil then
		if enumTypeName(weight) ~= "FontWeight" then
			error("Font.new: weight must be an Enum.FontWeight", 2)
		end
		if not FONTS[name][weight.Value] then
			table.insert(M.warnings, ("Font %s has no weight %d (Roblox will substitute)"):format(name, weight.Value))
		end
	end
	if style ~= nil and enumTypeName(style) ~= "FontStyle" then
		error("Font.new: style must be an Enum.FontStyle", 2)
	end
	return datatype("Font", { Family = family, Weight = weight, Style = style })
end
function Font.fromEnum(e: any)
	assert(enumTypeName(e) == "Font", "Font.fromEnum expects Enum.Font")
	return datatype("Font", { Family = "enum", Weight = nil, Style = nil })
end

local Random = {}
function Random.new(seed: number?)
	local state = seed or math.random(1, 2 ^ 30)
	local function next01()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return datatype("Random", {}, {
		__index = function(_, k)
			if k == "NextInteger" then
				return function(_, a: number, b: number)
					if type(a) ~= "number" or type(b) ~= "number" or a % 1 ~= 0 or b % 1 ~= 0 then
						error("NextInteger expects integers", 2)
					end
					if a > b then
						error("NextInteger: min > max", 2)
					end
					return a + math.floor(next01() * (b - a + 1))
				end
			elseif k == "NextNumber" then
				return function(_, a: number?, b: number?)
					local lo, hi = a or 0, b or 1
					return lo + next01() * (hi - lo)
				end
			end
			error(tostring(k) .. " is not a valid member of Random", 2)
		end,
	})
end

---------------------------------------------------------------- signals

local Signal = {}
Signal.__index = Signal
local function newSignal(name: string, filter: ((any, any) -> boolean)?)
	return setmetatable({ name = name, conns = {}, filter = filter }, Signal)
end
function Signal:Connect(fn)
	if type(fn) ~= "function" then
		error(self.name .. ":Connect expects a function", 2)
	end
	local conn = { fn = fn, vm = currentVM, connected = true }
	table.insert(self.conns, conn)
	return {
		Connected = true,
		Disconnect = function()
			conn.connected = false
		end,
	}
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c.Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Wait()
	local co = coroutine.running()
	local vm = currentVM
	local c
	c = self:Connect(function(...)
		c.Disconnect()
		schedule(now, co, vm, ...)
	end)
	return coroutine.yield()
end
-- Deferred: handlers run at the next scheduler step, like Roblox's default SignalBehavior.
function Signal:Fire(...)
	for _, conn in self.conns do
		if conn.connected and (not self.filter or self.filter(conn, ...)) then
			schedule(now, coroutine.create(conn.fn), conn.vm, ...)
		end
	end
end
function Signal:FireFiltered(filter, ...)
	for _, conn in self.conns do
		if conn.connected and filter(conn) then
			schedule(now, coroutine.create(conn.fn), conn.vm, ...)
		end
	end
end

---------------------------------------------------------------- instances

local data = setmetatable({}, { __mode = "k" }) -- inst -> internal record
M.sources = setmetatable({}, { __mode = "k" }) :: { [any]: { source: string, path: string } }

local function isInstance(v: any): boolean
	return type(v) == "table" and getmetatable(v) == InstanceMT
end
M.isInstance = isInstance

local function classIsA(className: string, target: string): boolean
	local c: string? = className
	while c do
		if c == target then
			return true
		end
		local info = API[c]
		c = info and info.super
	end
	return false
end

local function findMember(className: string, member: string): any
	local c: string? = className
	while c do
		local info = API[c]
		if not info then
			return nil
		end
		local m = info.members[member]
		if m then
			return m
		end
		c = info.super
	end
	return nil
end

local TRUE_BY_DEFAULT = {
	Visible = true,
	Enabled = true,
	AutoButtonColor = true,
	Archivable = true,
	ResetOnSpawn = true,
	Active = false,
}

local function parseDefault(m: any, propName: string): any
	local cat, name = m.t:match("^(%w+):(.+)$")
	local d = m.d
	if cat == "Primitive" then
		if name == "bool" then
			if d == "true" then
				return true
			elseif d == "false" then
				return false
			end
			return TRUE_BY_DEFAULT[propName] or false
		elseif name == "string" then
			return if d and not d:find("^__api_dump") then d else ""
		else
			local n = d and tonumber(d)
			if propName == "Scale" then
				return n or 1
			end
			return n or 0
		end
	elseif cat == "Enum" then
		local items = EnumItems[name]
		if items and d and items[d] then
			return items[d]
		end
		return nil
	elseif cat == "DataType" then
		if name == "UDim2" then
			return UDim2.new(0, 0, 0, 0)
		elseif name == "UDim" then
			return UDim.new(0, 0)
		elseif name == "Vector2" then
			if propName == "AbsoluteSize" then
				return Vector2.new(800, 500)
			end
			return Vector2.new(0, 0)
		elseif name == "Vector3" then
			return Vector3.new(0, 0, 0)
		elseif name == "Color3" then
			return Color3.new(0.5, 0.5, 0.5)
		elseif name == "Content" or name == "ContentId" then
			return ""
		end
		return nil
	end
	return nil
end

local function checkValue(m: any, v: any): boolean
	local cat, name = m.t:match("^(%w+):(.+)$")
	if cat == "Primitive" then
		if name == "bool" then
			return type(v) == "boolean"
		elseif name == "string" then
			return type(v) == "string"
		end
		return type(v) == "number"
	elseif cat == "Enum" then
		return enumTypeName(v) == name
	elseif cat == "Class" then
		return v == nil or (isInstance(v) and classIsA(data[v].className, name))
	elseif cat == "DataType" then
		if name == "Content" or name == "ContentId" then
			return type(v) == "string"
		end
		return typeOf(v) == name
	end
	return false
end

local methods: { [string]: any } = {}
local classMethods: { [string]: { [string]: any } } = {}

local function newInstance(className: string, bypass: boolean?): any
	local info = API[className]
	if not info then
		error(("Unable to create an Instance of type \"%s\""):format(className), 3)
	end
	if not bypass and (not info.creatable or info.service) then
		error(("Unable to create an Instance of type \"%s\""):format(className), 3)
	end
	local inst = setmetatable({}, InstanceMT)
	data[inst] = {
		className = className,
		props = { Name = className },
		children = {},
		parent = nil,
		signals = {},
		propSignals = {},
		attrs = {},
		destroyed = false,
	}
	return inst
end
M.newInstance = newInstance

local function getSignal(inst: any, name: string): any
	local d = data[inst]
	local s = d.signals[name]
	if not s then
		s = newSignal(d.className .. "." .. name)
		d.signals[name] = s
	end
	return s
end

local function setParent(inst: any, parent: any)
	local d = data[inst]
	if d.destroyed then
		error(("The Parent property of %s is locked"):format(d.props.Name), 3)
	end
	if parent ~= nil and not isInstance(parent) then
		error("Parent must be an Instance", 3)
	end
	local p = parent
	while p do
		if p == inst then
			error("Attempt to set parent of " .. d.props.Name .. " to itself or a descendant", 3)
		end
		p = data[p].parent
	end
	if d.parent then
		local siblings = data[d.parent].children
		local i = table.find(siblings, inst)
		if i then
			table.remove(siblings, i)
		end
	end
	d.parent = parent
	if parent then
		table.insert(data[parent].children, inst)
		local ca = data[parent].signals.ChildAdded
		if ca then
			ca:Fire(inst)
		end
	end
end

InstanceMT.__index = function(inst, key)
	local d = data[inst]
	if key == "ClassName" then
		return d.className
	elseif key == "Parent" then
		return d.parent
	end
	local v = d.props[key]
	if v ~= nil then
		return v
	end
	local m = findMember(d.className, key)
	if m then
		if m.k == "P" then
			if m.hid then
				error(("%s is not a valid member of %s (not scriptable)"):format(key, d.className), 2)
			end
			return parseDefault(m, key)
		elseif m.k == "E" then
			return getSignal(inst, key)
		elseif m.k == "F" then
			local cm = classMethods[d.className]
			local c: string? = d.className
			while c do
				cm = classMethods[c]
				if cm and cm[key] then
					return cm[key]
				end
				c = API[c] and API[c].super
			end
			if methods[key] then
				return methods[key]
			end
			error(("mock: %s:%s() is a real method but isn't mocked"):format(d.className, key), 2)
		elseif m.k == "C" then
			return nil
		end
	end
	for _, child in d.children do
		if data[child].props.Name == key then
			return child
		end
	end
	error(("%s is not a valid member of %s \"%s\""):format(tostring(key), d.className, tostring(d.props.Name)), 2)
end

InstanceMT.__newindex = function(inst, key, value)
	local d = data[inst]
	if key == "Parent" then
		setParent(inst, value)
		return
	end
	local m = findMember(d.className, key)
	if not m then
		error(("%s is not a valid member of %s"):format(tostring(key), d.className), 2)
	end
	if m.k == "C" then
		if value ~= nil and type(value) ~= "function" then
			error(key .. " must be a function", 2)
		end
		d.props[key] = value
		return
	end
	if m.k ~= "P" then
		error(("Can't assign to %s.%s (it's not a property)"):format(d.className, key), 2)
	end
	if m.ro and not d.allowWrite then
		error(("Unable to assign property %s. Property is read only"):format(key), 2)
	end
	if not checkValue(m, value) then
		error(("Unable to assign property %s. %s expected, got %s"):format(key, m.t, typeOf(value)), 2)
	end
	d.props[key] = value
	local ps = d.propSignals[key]
	if ps then
		ps:Fire()
	end
	local changed = d.signals.Changed
	if changed then
		if classIsA(d.className, "ValueBase") and key == "Value" then
			changed:Fire(value)
		elseif not classIsA(d.className, "ValueBase") then
			changed:Fire(key)
		end
	end
end

InstanceMT.__tostring = function(inst)
	return data[inst].props.Name
end

local function setInternal(inst: any, key: string, value: any)
	data[inst].props[key] = value
end
M.setInternal = setInternal

local function descendants(inst: any, out: { any })
	for _, c in data[inst].children do
		table.insert(out, c)
		descendants(c, out)
	end
	return out
end

methods.GetChildren = function(self)
	return table.clone(data[self].children)
end
methods.GetDescendants = function(self)
	return descendants(self, {})
end
methods.FindFirstChild = function(self, name, recursive)
	local list = if recursive then descendants(self, {}) else data[self].children
	for _, c in list do
		if data[c].props.Name == name then
			return c
		end
	end
	return nil
end
methods.FindFirstChildOfClass = function(self, className)
	for _, c in data[self].children do
		if data[c].className == className then
			return c
		end
	end
	return nil
end
methods.FindFirstChildWhichIsA = function(self, className)
	for _, c in data[self].children do
		if classIsA(data[c].className, className) then
			return c
		end
	end
	return nil
end
methods.FindFirstAncestorOfClass = function(self, className)
	local p = data[self].parent
	while p do
		if data[p].className == className then
			return p
		end
		p = data[p].parent
	end
	return nil
end
methods.WaitForChild = function(self, name, timeout)
	local deadline = now + (timeout or 5)
	while true do
		local c = methods.FindFirstChild(self, name)
		if c then
			return c
		end
		if now >= deadline then
			if timeout then
				return nil
			end
			error(("Infinite yield: %s:WaitForChild(\"%s\")"):format(data[self].props.Name, name), 2)
		end
		taskLib.wait(0.1)
	end
end
methods.IsA = function(self, className)
	return classIsA(data[self].className, className)
end
methods.IsDescendantOf = function(self, ancestor)
	local p = data[self].parent
	while p do
		if p == ancestor then
			return true
		end
		p = data[p].parent
	end
	return false
end
methods.IsAncestorOf = function(self, other)
	return methods.IsDescendantOf(other, self)
end
methods.Destroy = function(self)
	local d = data[self]
	for _, c in table.clone(d.children) do
		methods.Destroy(c)
	end
	if d.parent then
		setParent(self, nil)
	end
	d.destroyed = true
end
methods.ClearAllChildren = function(self)
	for _, c in table.clone(data[self].children) do
		methods.Destroy(c)
	end
end
methods.GetFullName = function(self)
	local parts = {}
	local p = self
	while p and data[p].className ~= "DataModel" do
		table.insert(parts, 1, data[p].props.Name)
		p = data[p].parent
	end
	return table.concat(parts, ".")
end
methods.SetAttribute = function(self, name, value)
	data[self].attrs[name] = value
end
methods.GetAttribute = function(self, name)
	return data[self].attrs[name]
end
methods.GetAttributes = function(self)
	return table.clone(data[self].attrs)
end
methods.GetPropertyChangedSignal = function(self, prop)
	local d = data[self]
	if not findMember(d.className, prop) then
		error(prop .. " is not a valid property of " .. d.className, 2)
	end
	local s = d.propSignals[prop]
	if not s then
		s = newSignal(d.className .. ".Changed:" .. prop)
		d.propSignals[prop] = s
	end
	return s
end
local function clone(self)
	local d = data[self]
	local copy = newInstance(d.className, true)
	local cd = data[copy]
	for k, v in d.props do
		cd.props[k] = v
	end
	for k, v in d.attrs do
		cd.attrs[k] = v
	end
	if M.sources[self] then
		M.sources[copy] = M.sources[self]
	end
	for _, c in d.children do
		setParent(clone(c), copy)
	end
	return copy
end
methods.Clone = clone

---------------------------------------------------------------- VMs (server + one per client)

local serverVM = { kind = "server", name = "server", modules = {}, G = {} }
M.serverVM = serverVM
local vms = { serverVM }

local game = newInstance("DataModel", true)
setInternal(game, "Name", "Game")
M.game = game

local function service(className: string): any
	for _, c in data[game].children do
		if data[c].className == className then
			return c
		end
	end
	local s = newInstance(className, true)
	if className == "Workspace" then
		setInternal(s, "Name", "Workspace")
	end
	setParent(s, game)
	return s
end
M.service = service

for _, name in {
	"Workspace",
	"Players",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterPlayer",
	"StarterGui",
	"Lighting",
	"SoundService",
	"TweenService",
	"RunService",
	"DataStoreService",
	"HttpService",
	"TextChatService",
} do
	service(name)
end
do
	local chatWindow = newInstance("ChatWindowConfiguration", true)
	setInternal(chatWindow, "Name", "ChatWindowConfiguration")
	setParent(chatWindow, service("TextChatService"))
end
classMethods.StarterGui = {
	SetCoreGuiEnabled = function(_, coreType, enabled)
		if enumTypeName(coreType) ~= "CoreGuiType" or type(enabled) ~= "boolean" then
			error("SetCoreGuiEnabled(Enum.CoreGuiType, boolean) expected", 2)
		end
	end,
	SetCore = function() end,
}
local camera = newInstance("Camera", true)
setInternal(camera, "Name", "Camera")
setParent(camera, service("Workspace"))
setInternal(service("Workspace"), "CurrentCamera", camera)
setInternal(camera, "ViewportSize", Vector2.new(1366, 768))

function M.setViewport(w: number, h: number)
	setInternal(camera, "ViewportSize", Vector2.new(w, h))
	local ps = data[camera].propSignals.ViewportSize
	if ps then
		ps:Fire()
	end
end

local starterPlayer = service("StarterPlayer")
local sps = newInstance("StarterPlayerScripts", true)
setInternal(sps, "Name", "StarterPlayerScripts")
setParent(sps, starterPlayer)

classMethods.DataModel = {
	GetService = function(_, name)
		local info = API[name]
		if not info or not info.service then
			error(("'%s' is not a valid Service name"):format(tostring(name)), 2)
		end
		return service(name)
	end,
	BindToClose = function(_, fn)
		M.closeHandlers = M.closeHandlers or {}
		table.insert(M.closeHandlers, { fn = fn, vm = currentVM })
	end,
}
classMethods.DataModel.FindService = classMethods.DataModel.GetService

-- Players
local Players = service("Players")
classMethods.Players = {
	GetPlayers = function(self)
		local out = {}
		for _, c in data[self].children do
			if data[c].className == "Player" then
				table.insert(out, c)
			end
		end
		return out
	end,
	GetPlayerByUserId = function(self, userId)
		for _, c in data[self].children do
			if data[c].className == "Player" and data[c].props.UserId == userId then
				return c
			end
		end
		return nil
	end,
	GetNameFromUserIdAsync = function(_, userId)
		taskLib.wait(0.05)
		return "User" .. tostring(userId)
	end,
}
-- LocalPlayer depends on which VM is asking.
local playersData = data[Players]
setmetatable(playersData.props, {
	__index = function(_, k)
		if k == "LocalPlayer" then
			return if currentVM and currentVM.kind == "client" then currentVM.player else nil
		end
		return nil
	end,
})

-- Workspace / RunService
classMethods.Workspace = {
	GetServerTimeNow = function()
		return 1000 + now
	end,
}
local RunService = service("RunService")
classMethods.RunService = {
	IsServer = function()
		return currentVM == serverVM
	end,
	IsClient = function()
		return currentVM ~= serverVM
	end,
	IsStudio = function()
		return true
	end,
}
table.insert(frameSignals, getSignal(RunService, "Heartbeat"))
table.insert(frameSignals, getSignal(RunService, "Stepped"))
do
	-- RenderStepped only exists on clients.
	local rs = getSignal(RunService, "RenderStepped")
	local origConnect = rs.Connect
	rs.Connect = function(self, fn)
		if currentVM == serverVM then
			error("RenderStepped event can only be used from local scripts", 2)
		end
		return origConnect(self, fn)
	end
	table.insert(frameSignals, rs)
end

-- SoundService / Sound
classMethods.SoundService = {
	PlayLocalSound = function(_, sound)
		if not isInstance(sound) or data[sound].className ~= "Sound" then
			error("PlayLocalSound expects a Sound", 2)
		end
	end,
}
classMethods.Sound = {
	Play = function() end,
	Stop = function() end,
	Pause = function() end,
	Resume = function() end,
}

-- TweenService / Tween
classMethods.TweenService = {
	Create = function(_, inst, info, goals)
		if not isInstance(inst) then
			error("TweenService:Create expects an Instance", 2)
		end
		if typeOf(info) ~= "TweenInfo" then
			error("TweenService:Create expects a TweenInfo", 2)
		end
		local d = data[inst]
		for prop, value in goals do
			local m = findMember(d.className, prop)
			if not m or m.k ~= "P" then
				error(("TweenService:Create property named '%s' cannot be tweened due to type mismatch (property is a 'nil', but given type is '%s')"):format(prop, typeOf(value)), 2)
			end
			if not checkValue(m, value) then
				error(("TweenService:Create property named '%s' cannot be tweened due to type mismatch (property is a '%s', but given type is '%s')"):format(prop, m.t, typeOf(value)), 2)
			end
			local cat = m.t:match("^(%w+):")
			if cat == "Enum" or cat == "Class" or m.t == "Primitive:string" or m.t == "Primitive:bool" then
				error(("TweenService:Create property named '%s' can't be tweened (%s)"):format(prop, m.t), 2)
			end
		end
		local tween = newInstance("Tween", true)
		data[tween].tween = { target = inst, info = info, goals = goals }
		return tween
	end,
}
classMethods.Tween = {
	Play = function(self)
		local t = data[self].tween
		if t.info.RepeatCount ~= 0 then
			return -- loops forever; never completes
		end
		t.playId = (t.playId or 0) + 1
		local id = t.playId
		local vm = currentVM
		schedule(now + t.info.Time + t.info.DelayTime, coroutine.create(function()
			if t.playId ~= id or data[t.target].destroyed then
				return
			end
			for prop, value in t.goals do
				t.target[prop] = value
			end
			getSignal(self, "Completed"):Fire(EnumItems.PlaybackState.Completed)
		end), vm)
	end,
	Cancel = function(self)
		local t = data[self].tween
		t.playId = (t.playId or 0) + 1
	end,
	Pause = function(self)
		local t = data[self].tween
		t.playId = (t.playId or 0) + 1
	end,
}

---------------------------------------------------------------- remotes

-- Copy a value the way Roblox serializes remote arguments, failing on things Roblox can't send.
local function serialize(v: any, path: string, stack: { [any]: boolean }): any
	local t = type(v)
	if t == "nil" or t == "boolean" or t == "number" or t == "string" then
		return v
	elseif t == "table" then
		if isInstance(v) then
			return v
		end
		local mt = getmetatable(v)
		if type(mt) == "table" and rawget(mt, "__type") then
			return v
		end
		if mt ~= nil then
			fail("remote: table with a metatable at " .. path .. " (metatable is dropped by Roblox)")
		end
		if stack[v] then
			fail("remote: cyclic table at " .. path)
			return nil
		end
		stack[v] = true
		local n = #v
		local numeric, stringy, other = 0, 0, 0
		for k in v do
			if type(k) == "number" then
				numeric += 1
				if k % 1 ~= 0 or k < 1 or k > n then
					fail(("remote: sparse/non-array number key %s at %s"):format(tostring(k), path))
				end
			elseif type(k) == "string" then
				stringy += 1
			else
				other += 1
			end
		end
		if numeric > 0 and stringy > 0 then
			fail("remote: mixed array/dictionary table at " .. path)
		end
		if other > 0 then
			fail("remote: table keys must be strings or array indices at " .. path)
		end
		local out = {}
		for k, val in v do
			out[k] = serialize(val, path .. "." .. tostring(k), stack)
		end
		stack[v] = nil
		return out
	else
		fail(("remote: can't send a %s at %s"):format(t, path))
		return nil
	end
end

local function serializeArgs(path: string, ...): any
	local args = table.pack(...)
	for i = 1, args.n do
		args[i] = serialize(args[i], path .. "[" .. i .. "]", {})
	end
	return args
end

classMethods.RemoteFunction = {
	InvokeServer = function(self, ...)
		local vm = currentVM
		if not vm or vm.kind ~= "client" then
			error("InvokeServer can only be called from the client", 2)
		end
		local handler = data[self].props.OnServerInvoke
		if not handler then
			error("mock: OnServerInvoke not set on " .. data[self].props.Name, 2)
		end
		local args = serializeArgs("InvokeServer(" .. data[self].props.Name .. ")", ...)
		taskLib.wait(0.03) -- network latency
		currentVM = serverVM
		local results = table.pack(pcall(handler, vm.player, table.unpack(args, 1, args.n)))
		currentVM = vm
		if not results[1] then
			fail("[server] OnServerInvoke(" .. data[self].props.Name .. ") error: " .. tostring(results[2]))
			error(results[2], 2)
		end
		local out = serializeArgs("InvokeServer result", table.unpack(results, 2, results.n))
		taskLib.wait(0.03)
		return table.unpack(out, 1, out.n)
	end,
}
classMethods.RemoteEvent = {
	FireClient = function(self, player, ...)
		if currentVM ~= serverVM then
			error("FireClient can only be called from the server", 2)
		end
		if not isInstance(player) or data[player].className ~= "Player" then
			error("FireClient: player argument must be a Player object", 2)
		end
		local args = serializeArgs("FireClient(" .. data[self].props.Name .. ")", ...)
		getSignal(self, "OnClientEvent"):FireFiltered(function(conn)
			return conn.vm and conn.vm.player == player
		end, table.unpack(args, 1, args.n))
	end,
	FireAllClients = function(self, ...)
		local args = serializeArgs("FireAllClients", ...)
		getSignal(self, "OnClientEvent"):FireFiltered(function(conn)
			return conn.vm and conn.vm.kind == "client"
		end, table.unpack(args, 1, args.n))
	end,
	FireServer = function(self, ...)
		local vm = currentVM
		local args = serializeArgs("FireServer", ...)
		getSignal(self, "OnServerEvent"):FireFiltered(function(conn)
			return conn.vm == serverVM
		end, vm.player, table.unpack(args, 1, args.n))
	end,
}

---------------------------------------------------------------- DataStores

M.datastoreFailing = false
local stores: { [string]: { [string]: any } } = {}

local function storeFor(name: string, ordered: boolean): any
	local className = if ordered then "OrderedDataStore" else "DataStore"
	local inst = newInstance(className, true)
	stores[name] = stores[name] or {}
	data[inst].store = stores[name]
	return inst
end

local function maybeFail()
	taskLib.wait(0.05)
	if M.datastoreFailing then
		error("502: API Services rejected request (mock)", 3)
	end
end

local function copyStored(v: any): any
	return serialize(v, "DataStore", {})
end

classMethods.DataStoreService = {
	GetDataStore = function(_, name)
		return storeFor("ds:" .. name, false)
	end,
	GetOrderedDataStore = function(_, name)
		return storeFor("ods:" .. name, true)
	end,
}
local storeMethods = {
	GetAsync = function(self, key)
		maybeFail()
		return copyStored(data[self].store[key])
	end,
	SetAsync = function(self, key, value)
		maybeFail()
		data[self].store[key] = copyStored(value)
	end,
	UpdateAsync = function(self, key, fn)
		maybeFail()
		local new = fn(copyStored(data[self].store[key]))
		if new ~= nil then
			data[self].store[key] = copyStored(new)
		end
		return new
	end,
	RemoveAsync = function(self, key)
		maybeFail()
		data[self].store[key] = nil
	end,
}
classMethods.DataStore = storeMethods
classMethods.GlobalDataStore = storeMethods
classMethods.OrderedDataStore = table.clone(storeMethods)
classMethods.OrderedDataStore.GetSortedAsync = function(self, ascending, pageSize)
	maybeFail()
	local list = {}
	for k, v in data[self].store do
		if type(v) ~= "number" or v % 1 ~= 0 then
			error("OrderedDataStore values must be integers", 2)
		end
		table.insert(list, { key = k, value = v })
	end
	table.sort(list, function(a, b)
		if ascending then
			return a.value < b.value
		end
		return a.value > b.value
	end)
	local page = {}
	for i = 1, math.min(pageSize, #list) do
		page[i] = list[i]
	end
	local pages = newInstance("DataStorePages", true)
	data[pages].page = page
	return pages
end
classMethods.DataStorePages = {
	GetCurrentPage = function(self)
		return data[self].page
	end,
}

---------------------------------------------------------------- script environments

local function makeEnv(vm: any, scriptInst: any): any
	local env = {
		script = scriptInst,
		game = game,
		workspace = service("Workspace"),
		Instance = {
			new = function(className, parent)
				local inst = newInstance(className)
				if parent then
					inst.Parent = parent
				end
				return inst
			end,
		},
		Enum = Enum,
		Color3 = Color3,
		UDim = UDim,
		UDim2 = UDim2,
		Vector2 = Vector2,
		Vector3 = Vector3,
		CFrame = CFrame,
		ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint,
		NumberSequence = NumberSequence,
		NumberSequenceKeypoint = NumberSequenceKeypoint,
		NumberRange = NumberRange,
		TweenInfo = TweenInfo,
		Font = Font,
		Random = Random,
		task = taskLib,
		typeof = typeOf,
		tick = function()
			return 1700000000 + now
		end,
		time = function()
			return now
		end,
		os = {
			clock = function()
				return now
			end,
			time = function()
				return 1700000000 + math.floor(now)
			end,
			date = os.date,
		},
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring((select(i, ...)))
			end
			table.insert(M.warnings, ("[%s] %s"):format(vm.name, table.concat(parts, " ")))
		end,
		print = function(...)
			if M.prints then
				print(("[%s]"):format(vm.name), ...)
			end
		end,
		require = function(target)
			if not isInstance(target) or data[target].className ~= "ModuleScript" then
				error("Attempted to call require with invalid argument(s).", 2)
			end
			local cached = vm.modules[target]
			if cached then
				if cached.loading then
					error("Requested module was required recursively", 2)
				end
				return cached.value
			end
			local src = M.sources[target]
			if not src then
				error("mock: no source for module " .. methods.GetFullName(target), 2)
			end
			local entry = { loading = true, value = nil }
			vm.modules[target] = entry
			local chunk, err = loadstring(src.source, "=" .. src.path)
			if not chunk then
				error("syntax error in " .. src.path .. ": " .. tostring(err), 2)
			end
			setfenv(chunk, M.makeEnv(vm, target))
			local results = table.pack(chunk())
			if results.n ~= 1 then
				error(("Module code did not return exactly one value (%s)"):format(src.path), 2)
			end
			entry.loading = false
			entry.value = results[1]
			return results[1]
		end,
		_G = vm.G,
		shared = vm.G,
	}
	return setmetatable(env, { __index = _G })
end
M.makeEnv = makeEnv

local function runScript(vm: any, inst: any)
	local src = M.sources[inst]
	local chunk, err = loadstring(src.source, "=" .. src.path)
	if not chunk then
		fail("syntax error in " .. src.path .. ": " .. tostring(err))
		return
	end
	setfenv(chunk, makeEnv(vm, inst))
	resume(coroutine.create(chunk), vm)
end

-- Build the Rojo tree into the DataModel.
local function build(node: any, parent: any)
	local inst
	local info = API[node.className]
	if info and info.service then
		inst = service(node.className)
	elseif node.className == "StarterPlayerScripts" then
		inst = sps
	else
		inst = newInstance(node.className, true)
		setInternal(inst, "Name", node.name)
		setParent(inst, parent)
	end
	if node.source then
		M.sources[inst] = { source = node.source, path = node.path }
	end
	for _, child in node.children do
		build(child, inst)
	end
end
for _, child in TREE.children do
	build(child, game)
end

function M.startServer()
	for _, inst in descendants(service("ServerScriptService"), {}) do
		if data[inst].className == "Script" then
			runScript(serverVM, inst)
		end
	end
	-- Workspace scripts too
	for _, inst in descendants(service("Workspace"), {}) do
		if data[inst].className == "Script" then
			runScript(serverVM, inst)
		end
	end
end

local nextUser = 0
function M.addPlayer(userId: number, name: string): any
	local player = newInstance("Player", true)
	local d = data[player]
	d.allowWrite = true
	player.Name = name
	player.UserId = userId
	player.DisplayName = name
	d.allowWrite = false
	local gui = newInstance("PlayerGui", true)
	setInternal(gui, "Name", "PlayerGui")
	setParent(gui, player)
	local scripts = newInstance("PlayerScripts", true)
	setInternal(scripts, "Name", "PlayerScripts")
	setParent(scripts, player)
	setParent(player, Players)
	nextUser += 1

	local vm = { kind = "client", name = "client:" .. name, player = player, modules = {}, G = {} }
	table.insert(vms, vm)
	getSignal(Players, "PlayerAdded"):Fire(player)

	for _, child in data[sps].children do
		setParent(clone(child), scripts)
	end
	for _, inst in descendants(scripts, {}) do
		if data[inst].className == "LocalScript" then
			runScript(vm, inst)
		end
	end
	return vm
end

function M.removePlayer(vm: any)
	local player = vm.player
	getSignal(Players, "PlayerRemoving"):Fire(player)
	-- With deferred signals the player is usually gone by the time handlers run.
	setParent(player, nil)
	vm.dead = true
end

function M.inVM(vm: any, fn: () -> ())
	resume(coroutine.create(fn), vm)
end

---------------------------------------------------------------- client UI helpers (for tests)

function M.data(inst: any)
	return data[inst]
end

local function effectivelyVisible(inst: any): boolean
	local p = inst
	while p do
		local d = data[p]
		if classIsA(d.className, "GuiObject") and d.props.Visible == false then
			return false
		end
		if d.className == "ScreenGui" and d.props.Enabled == false then
			return false
		end
		if d.className == "PlayerGui" then
			return true
		end
		p = d.parent
	end
	return false
end
M.effectivelyVisible = effectivelyVisible

function M.gui(vm: any): any
	return methods.FindFirstChild(vm.player, "PlayerGui")
end

function M.findAll(vm: any, pred: (any) -> boolean): { any }
	local out = {}
	for _, inst in descendants(M.gui(vm), {}) do
		if pred(inst) then
			table.insert(out, inst)
		end
	end
	return out
end

function M.visibleButtons(vm: any): { any }
	return M.findAll(vm, function(inst)
		return classIsA(data[inst].className, "GuiButton") and effectivelyVisible(inst)
	end)
end

function M.button(vm: any, name: string): any?
	for _, b in M.visibleButtons(vm) do
		if data[b].props.Name == name then
			return b
		end
	end
	return nil
end

function M.click(vm: any, name: string): boolean
	local b = M.button(vm, name)
	if not b then
		local names = {}
		for _, v in M.visibleButtons(vm) do
			table.insert(names, data[v].props.Name)
		end
		fail(("[%s] no visible button '%s' (visible: %s)"):format(vm.name, name, table.concat(names, ", ")))
		return false
	end
	getSignal(b, "MouseEnter"):Fire()
	getSignal(b, "MouseButton1Down"):Fire()
	getSignal(b, "MouseButton1Up"):Fire()
	getSignal(b, "Activated"):Fire()
	return true
end

function M.visibleText(vm: any, needle: string): boolean
	for _, inst in descendants(M.gui(vm), {}) do
		local d = data[inst]
		if (d.className == "TextLabel" or d.className == "TextButton") and effectivelyVisible(inst) then
			local text = d.props.Text
			if type(text) == "string" and text:find(needle, 1, true) then
				return true
			end
		end
	end
	return false
end

---------------------------------------------------------------- layout check

-- Estimate every visible element's on-screen rectangle for a screen size, and report:
--   overflow  - element (or a list/grid's contents) sticks out of its parent
--   tiny text - TextScaled text that would end up smaller than `minText` px
function M.layoutCheck(vm: any, screenW: number, screenH: number, minText: number): { string }
	local issues = {}
	local function prop(inst: any, key: string, default: any): any
		local v = data[inst].props[key]
		if v == nil then
			return default
		end
		return v
	end
	local function name(inst: any): string
		return methods.GetFullName(inst):gsub("^Players%.[^%.]+%.PlayerGui%.", "")
	end
	local function childOfClass(inst: any, className: string): any
		for _, c in data[inst].children do
			if data[c].className == className then
				return c
			end
		end
		return nil
	end
	local function contentBox(inst: any, x: number, y: number, w: number, h: number)
		local pad = childOfClass(inst, "UIPadding")
		if pad then
			local function px(u: any, total: number): number
				return if u then u.Scale * total + u.Offset else 0
			end
			local l, r = px(prop(pad, "PaddingLeft", nil), w), px(prop(pad, "PaddingRight", nil), w)
			local t, b = px(prop(pad, "PaddingTop", nil), h), px(prop(pad, "PaddingBottom", nil), h)
			return x + l, y + t, w - l - r, h - t - b
		end
		return x, y, w, h
	end

	local function textSize(inst: any, w: number, h: number): number
		local text = prop(inst, "Text", "")
		if prop(inst, "RichText", false) then
			text = text:gsub("<[^>]+>", "")
		end
		if text == "" then
			return 999
		end
		local maxSize = 100
		local c = childOfClass(inst, "UITextSizeConstraint")
		if c then
			maxSize = prop(c, "MaxTextSize", 100)
		end
		local lines = 0
		local longest = 0
		for line in (text .. "\n"):gmatch("(.-)\n") do
			lines += 1
			longest = math.max(longest, #line)
		end
		-- Average glyph is ~0.55em wide, line height ~1.2em.
		local byHeight = h / (lines * 1.2)
		local byWidth = w / math.max(1, longest * 0.55)
		local size = math.min(byHeight, byWidth)
		if prop(inst, "TextWrapped", false) and byWidth < byHeight then
			-- Wrapping lets long text use more lines.
			local chars = #text
			size = math.sqrt((w * h) / (chars * 0.55 * 1.2))
			size = math.min(size, byHeight)
		end
		return math.min(size, maxSize)
	end

	local function walk(inst: any, x: number, y: number, w: number, h: number)
		local cx, cy, cw, ch = contentBox(inst, x, y, w, h)
		local list = childOfClass(inst, "UIListLayout")
		local grid = childOfClass(inst, "UIGridLayout")
		local scrolling = data[inst].className == "ScrollingFrame"
		local kids = {}
		for _, c in data[inst].children do
			if classIsA(data[c].className, "GuiObject") and prop(c, "Visible", true) then
				table.insert(kids, c)
			end
		end

		local totalMain = 0
		for _, c in kids do
			local size = prop(c, "Size", nil)
			local sw = if size then cw * size.X.Scale + size.X.Offset else 100
			local sh = if size then ch * size.Y.Scale + size.Y.Offset else 100
			local sc = childOfClass(c, "UISizeConstraint")
			if sc then
				local mn, mx = prop(sc, "MinSize", Vector2.new(0, 0)), prop(sc, "MaxSize", Vector2.new(1e9, 1e9))
				sw = math.clamp(sw, mn.X, mx.X)
				sh = math.clamp(sh, mn.Y, mx.Y)
			end
			local ar = childOfClass(c, "UIAspectRatioConstraint")
			if ar then
				local ratio = prop(ar, "AspectRatio", 1)
				if sw / ratio > sh then
					sw = sh * ratio
				else
					sh = sw / ratio
				end
			end
			if grid then
				local cell = prop(grid, "CellSize", UDim2.new(0, 100, 0, 100))
				sw = cw * cell.X.Scale + cell.X.Offset
				sh = ch * cell.Y.Scale + cell.Y.Offset
			end
			local px, py
			if list or grid then
				px, py = cx, cy -- position managed by the layout; checked as a whole below
				if list then
					local horizontal = prop(list, "FillDirection", nil) == Enum.FillDirection.Horizontal
					totalMain += if horizontal then sw else sh
				end
			else
				local pos = prop(c, "Position", UDim2.new(0, 0, 0, 0))
				local anchor = prop(c, "AnchorPoint", Vector2.new(0, 0))
				px = cx + cw * pos.X.Scale + pos.X.Offset - anchor.X * sw
				py = cy + ch * pos.Y.Scale + pos.Y.Offset - anchor.Y * sh
				local rotated = prop(c, "Rotation", 0) ~= 0
				local allowed = prop(inst, "ClipsDescendants", false) or data[c].attrs.AllowOverflow
				if not scrolling and not rotated and not allowed
					and (px < cx - 3 or py < cy - 3 or px + sw > cx + cw + 3 or py + sh > cy + ch + 3)
				then
					table.insert(issues, ("overflow  %s  (%.0fx%.0f at %.0f,%.0f in %.0fx%.0f at %.0f,%.0f)"):format(
						name(c), sw, sh, px, py, cw, ch, cx, cy))
				end
			end
			local cls = data[c].className
			if (sw <= 0 or sh <= 0) and (cls == "TextLabel" or cls == "TextButton") then
				table.insert(issues, ("zero size  %s"):format(name(c)))
			end
			if (cls == "TextLabel" or cls == "TextButton" or cls == "TextBox")
				and childOfClass(c, "UIGradient")
				and prop(c, "BackgroundTransparency", 0) < 1
				and prop(c, "Text", "") ~= ""
			then
				table.insert(issues, ("gradient tints text  %s  \"%s\""):format(name(c), tostring(prop(c, "Text", "")):sub(1, 30)))
			end
			if (cls == "TextLabel" or cls == "TextButton" or cls == "TextBox") and prop(c, "TextScaled", false) then
				local tw, th = sw, sh
				local tpad = childOfClass(c, "UIPadding")
				if tpad then
					local _, _, w2, h2 = contentBox(c, 0, 0, sw, sh)
					tw, th = w2, h2
				end
				local size = textSize(c, tw, th)
				if size < minText then
					table.insert(issues, ("tiny text %4.1fpx  %s  \"%s\""):format(size, name(c), tostring(prop(c, "Text", "")):sub(1, 40)))
				end
			end
			walk(c, px, py, sw, sh)
		end

		if list and #kids > 0 and not scrolling then
			local horizontal = prop(list, "FillDirection", nil) == Enum.FillDirection.Horizontal
			local padding = prop(list, "Padding", UDim.new(0, 0))
			local available = if horizontal then cw else ch
			local total = totalMain + (#kids - 1) * (padding.Scale * available + padding.Offset)
			if total > available + 3 then
				table.insert(issues, ("list overflow  %s  (%.0f > %.0f)"):format(name(inst), total, available))
			end
		end
		if grid and #kids > 0 then
			local cell = prop(grid, "CellSize", UDim2.new(0, 100, 0, 100))
			local pad = prop(grid, "CellPadding", UDim2.new(0, 5, 0, 5))
			local cellW, cellH = cw * cell.X.Scale + cell.X.Offset, ch * cell.Y.Scale + cell.Y.Offset
			local padW, padH = cw * pad.X.Scale + pad.X.Offset, ch * pad.Y.Scale + pad.Y.Offset
			local perRow = math.max(1, math.floor((cw + padW) / (cellW + padW)))
			local rows = math.ceil(#kids / perRow)
			local total = rows * cellH + (rows - 1) * padH
			if total > ch + 3 then
				table.insert(issues, ("grid overflow  %s  (%d rows, %.0f > %.0f)"):format(name(inst), rows, total, ch))
			end
		end
	end

	for _, sg in data[M.gui(vm)].children do
		if data[sg].className == "ScreenGui" and prop(sg, "Enabled", true) then
			local inset = if prop(sg, "IgnoreGuiInset", false) then 0 else 58
			walk(sg, 0, inset, screenW, screenH - inset)
		end
	end
	return issues
end

function M.serverModule(path: string): any
	for inst, entry in serverVM.modules do
		local src = M.sources[inst]
		if src and src.path == path then
			return entry.value
		end
	end
	return nil
end

return M
