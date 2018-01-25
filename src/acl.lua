--
-- Axcell
-- Copyright (C) 2017 tacigar
--

local util = require "axcell.util"

-- Forward declarations.
local Formula
local FormulaBinary
local FormulaNegation
local FormulaResource
local FormulaType
local Principal
local PrincipalCompound
local PrincipalName
local PrincipalType
local PrincipalVariable
local ReferenceMonitor

-------------------------------------------------
-- FormulaType enum.
local _FormulaType = {
	IMPLICATION  =  1, IMP   =  1,
	LOGICAL_AND  =  2, LAND  =  2,
	LOGICAL_OR   =  3, LOR   =  3,
	NEGATION     =  4, NEG   =  4,
	FACT         =  5, -- No alias
	RESOURCE     =  6, RES   =  6,
	SAYS         =  7, -- No alias
	CONTROLS     =  8, CTRL  =  8,
	SPEAKS_FOR   =  9, SPKF  =  9,
	PREDICATE    = 10, PRED  = 10,
}

FormulaType = setmetatable({}, {
	__index = function(_, key)
		if _FormulaType[key] then
			return _FormulaType[key]
		end
		error(string.format("FormulaType don't have such a value: %s", key))
	end,
	__newindex = function(_, _, _)
		error("Attempt to modify read-only table: FormulaType")
	end,
	__metatable = false,
})

-------------------------------------------------
-- CloningType enum.
local _CloningType = {
	BIDIRECTIONAL  = 1,
	SUCCEEDING     = 2,
}

local CloningType = setmetatable({}, {
	__index = function(_, key)
		if _CloningType[key] then
			return _CloningType[key]
		end
		error(string.format("CloningType don't have such a value: %s", key))
	end,
	__newindex = function(_, _, _)
		error("Attempt to modify read-only table: CloningType")
	end,
	__metatable = false,
})

-------------------------------------------------
-- Formula class.
Formula = {}
Formula.__index = Formula

function Formula.new(params)
	if not params.type then
		error("need \"type\" field.")
	end
	return setmetatable(params, Formula)
end

setmetatable(Formula, {
	__call = function(_, params)
		return Formula.new(params)
	end,
})

function Formula:implication(other)
	return FormulaBinary {
		lhs = self:clone(CloningType.SUCCEEDING),
		rhs = other:clone(CloningType.SUCCEEDING),
		type = FormulaType.IMPLICATION,
	}
end
Formula.imp = Formula.implication -- alias

function Formula:logicalAnd(other)
	return FormulaBinary {
		lhs = self:clone(CloningType.SUCCEEDING),
		rhs = other:clone(CloningType.SUCCEEDING),
		type = FormulaType.LOGICAL_AND,
	}
end
Formula.land = Formula.logicalAnd -- alias

function Formula:logicalOr(other)
	return FormulaBinary {
		lhs = self:clone(CloningType.SUCCEEDING),
		rhs = other:clone(CloningType.SUCCEEDING),
		type = FormulaType.LOGICAL_OR,
	}
end
Formula.lor = Formula.logicalOr -- alias

function Formula:getType()
	return self.type
end

function Formula:getTop()
	local current = self
	while current.parent do
		current = current.parent
	end
	return current
end

function Formula:getParent()
	return self.parent
end

-------------------------------------------------
-- FormulaBinary class.
FormulaBinary = {}
FormulaBinary.__index = FormulaBinary

function FormulaBinary.new(params)
	local lhs = params.lhs or error "need \"lhs\" field."
	local rhs = params.rhs or error "need \"rhs\" field."
	local type = params.type or error "need \"type\" field."
	local f = {
		lhs = lhs,
		rhs = rhs,
		type = type,
		parent = nil,
	}
	lhs.parent = f
	rhs.parent = f
	return setmetatable(f, FormulaBinary)
end

setmetatable(FormulaBinary, {
	__call = function(_, params)
		return FormulaBinary.new(params)
	end,
	__index = Formula,
})

function FormulaBinary:getRHS()
	return self.rhs
end

function FormulaBinary:getLHS()
	return self.lhs
end

function FormulaBinary:clone(cloningType, ...)
	if cloningType == CloningType.BIDIRECTIONAL then
		local args = {...}
		local caller = args[1]
		local newCaller = args[2]
		if caller == nil then
			local lhs = self.lhs:clone(CloningType.SUCCEEDING)
			local rhs = self.rhs:clone(CloningType.SUCCEEDING)
			local f = FormulaBinary {
				lhs = lhs,
				rhs = rhs,
				type = self.type,
			}
			if self.parent then
				self.parent:clone(CloningType.BIDIRECTIONAL, self, f)
			end
			return f
		else
			if caller == self.lhs then
				local rhs = self.rhs:clone(CloningType.SUCCEEDING)
				local f = FormulaBinary {
					lhs = newCaller,
					rhs = rhs,
					type = self.type,
				}
				if self.parent then
					self.parent:clone(CloningType.BIDIRECTIONAL, self, f)
				end
				return f
			elseif caller == self.rhs then
				local lhs = self.lhs:clone(CloningType.SUCCEEDING)
				local f = FormulaBinary {
					lhs = lhs,
					rhs = newCaller,
					type = self.type,
				}
				if self.parent then
					self.parent:clone(CloningType.BIDIRECTIONAL, self, f)
				end
				return f
			else
				error("Cloning error")
			end
		end
	elseif cloningType == CloningType.SUCCEEDING then
		local lhs = self.lhs:clone(CloningType.SUCCEEDING)
		local rhs = self.rhs:clone(CloningType.SUCCEEDING)
		local f = FormulaBinary {
			lhs = lhs,
			rhs = rhs,
			type = self.type,
		}
		return f
	end
end

function FormulaBinary:match(other)
	if self.type ~= other.type then
		return false, nil
	end
	local lb, lcaps = self.lhs:match(other.lhs)
	if not lb then
		return false, nil
	end
	local rb, rcaps = self.rhs:match(other.rhs)
	if not rb then
		return false, nil
	end
	return true, {
		lhs = util.table.merge(lcaps.lhs, rcaps.lhs),
		rhs = util.table.merge(lcaps.rhs, rcaps.rhs),
	}
end

function FormulaBinary:__tostring()
	if self.type == FormulaType.IMPLICATION then
		return string.format("(%s) \u{2283} (%s)", tostring(self.lhs), tostring(self.rhs))
	elseif self.type == FormulaType.LOGICAL_AND then
		return string.format("(%s) \u{2227} (%s)", tostring(self.lhs), tostring(self.rhs))
	elseif self.type == FormulaType.LOGICAL_OR then
		return string.format("(%s) \u{2228} (%s)", tostring(self.lhs), tostring(self.rhs))
	elseif self.type == FormulaType.SAYS then
		return string.format("(%s) says (%s)", tostring(self.lhs), tostring(self.rhs))
	elseif self.type == FormulaType.SPEAKS_FOR then
		return string.format("(%s) \u{21D2} (%s)", tostring(self.lhs), tostring(self.rhs))
	end
end

-------------------------------------------------
-- FormulaNegation class.
FormulaNegation = {}
FormulaNegation.__index = FormulaNegation

function FormulaNegation.new(operand)
	local f = {
		operand = operand,
		type = FormulaType.NEGATION,
		parent = nil,
	}
	operand.parent = f
	return setmetatable(f, FormulaNegation)
end

setmetatable(FormulaNegation, {
	__call = function(_, operand)
		return FormulaNegation.new(operand)
	end,
	__index = Formula,
})

function FormulaNegation:getOperand()
	return self.operand
end

function FormulaNegation:clone(cloningType, ...)
	if cloningType == CloningType.BIDIRECTIONAL then
		local args = {...}
		local caller = args[1]
		local newCaller = args[2]
		if caller == nil then
			local operand = self.operand:clone(CloningType.SUCCEEDING)
			local f = FormulaNegation(operand)
			if self.parent then
				self.parent:clone(CloningType.BIDIRECTIONAL, self, f)
			end
			return f
		else
			if caller == self.operand then
				local f = FormulaNegation(newCaller)
				if self.parent then
					self.parent:clone(CloningType.BIDIRECTIONAL, self, f)
				end
				return f
			else
				error("Cloning error")
			end
		end
	elseif cloningType == CloningType.SUCCEEDING then
		local operand = self.operand:clone(CloningType.SUCCEEDING)
		local f = FormulaNegation(operand)
		return f
	end
end

function FormulaNegation:__tostring()
	return string.format("\u{00AC} (%s)", tostring(self.expr))
end

-------------------------------------------------
-- FormulaResource class.
FormulaResource = {}
FormulaResource.__index = FormulaResource

function FormulaResource.new(name)
	return setmetatable({
		name = name,
		type = FormulaType.RESOURCE,
	}, FormulaResource)
end

setmetatable(FormulaResource, {
	__call = function(_, name)
		return FormulaResource.new(name)
	end,
	__index = Formula,
})

function FormulaResource:getName()
	return self.name
end

function FormulaResource:clone(cloningType)
	if cloningType == CloningType.BIDIRECTIONAL then
		local f = FormulaResource(self.name)
		if self.parent then
			self.parent:clone(CloningType.BIDIRECTIONAL, self, f)
		end
		return f
	elseif cloningType == CloningType.SUCCEEDING then
		return FormulaResource(self.name)
	end
end

function FormulaResource:equals(other)
	if other.type ~= FormulaType.RESOURCE then
		return false
	end
	return self.name == other.name
end

function FormulaResource:match(other)
	if other.type ~= FormulaType.RESOURCE then
		return false, nil
	end
	if self.name == other.name then
		return true, { lhs = {}, rhs = {} }
	else
		return false, nil
	end
end

function FormulaResource:__tostring()
	return string.format("Res{%s}", self.name)
end

-------------------------------------------------
-- PrincipalType enum.
local _PrincipalType = {
	PNAME        = 1, -- No alias
	VARIABLE     = 2, VAR   = 2,
	CONJUNCTION  = 3, CONJ  = 3,
	QUOTING      = 4, QUOT  = 4,
}

PrincipalType = setmetatable({}, {
	__index = function(_, key)
		if _PrincipalType[key] then
			return _PrincipalType[key]
		end
		error(string.format("PrincipalType don't have such a value: %s", key))
	end,
	__newindex = function(_, _ ,_)
		error("Attempt to modify read-only table: PrincipalType")
	end,
	__metatable = false,
})


-------------------------------------------------
-- Principal class.
Principal = {}
Principal.__index = Principal

function Principal.new(params)
	if not params.type then
		error("need \"type\" field.")
	end
	return setmetatable(params, Principal)
end

setmetatable(Principal, {
	__call = function(_, params)
		return Principal.new(params)
	end
})

function Principal:conjunction(other)
	return PrincipalCompound {
		lhs = self:clone(),
		rhs = other:clone(),
		type = PrincipalType.CONJUNCTION,
	}
end
Principal.conj = Principal.conjunction

function Principal:quoting(other)
	return PrincipalCompound {
		lhs = self:clone(),
		rhs = other:clone(),
		type = PrincipalType.QUOTING,
	}
end
Principal.quot = Principal.quoting

-------------------------------------------------
-- PrincipalCompound class.
PrincipalCompound = {}
PrincipalCompound.__index = PrincipalCompound

function PrincipalCompound.new(params)
	local lhs = params.lhs or error "need \"lhs\" field."
	local rhs = params.lhs or error "need \"rhs\" field."
	local type = params.type or error "need \"type\" field."
	local f = {
		lhs = lhs,
		rhs = rhs,
		type = type,
	}
	return setmetatable(f, PrincipalCompound)
end

setmetatable(PrincipalCompound, {
	__call = function(_, params)
		return PrincipalCompound.new(params)
	end,
	__index = Principal,
})

function PrincipalCompound:says(formula)
	if self.type == PrincipalType.CONJUNCTION then
		return self.lhs:says(formula):logicalAnd(self.rhs:says(formula))
	elseif self.type == PrincipalType.QUOTING then
		return self.lhs:says(self.rhs:says(formula))
	end
end

-------------------------------------------------
-- PrincipalName class.
PrincipalName = {}
PrincipalName.__index = PrincipalName

function PrincipalName.new(name)
	return setmetatable({
		name = name,
		type = PrincipalType.PNAME,
	}, PrincipalName)
end

setmetatable(PrincipalName, {
	__call = function(_, name)
		return PrincipalName.new(name)
	end,
	__index = Principal,
})

function PrincipalName:says(formula)
	return FormulaBinary {
		lhs = self:clone(),
		rhs = formula:clone(CloningType.SUCCEEDING),
		type = FormulaType.SAYS,
	}
end

function PrincipalName:controls(formula)
	local says = self:says(formula)
	return says:implication(formula)
end

function PrincipalName:speaksFor(other)
	return FormulaBinary {
		lhs = self:clone(),
		rhs = other:clone(),
		type = FormulaType.SPEAKS_FOR,
	}
end

function PrincipalName:clone()
	return PrincipalName(self.name)
end

function PrincipalName:__tostring()
	return string.format("PName{\"%s\"}", self.name)
end

-------------------------------------------------
-- PrincipalVariable class.
PrincipalVariable = {}
PrincipalVariable.__index = PrincipalVariable

function PrincipalVariable.new(name)
	return setmetatable({
		name = name,
		type = PrincipalType.VARIABLE,
	}, PrincipalVariable)
end

setmetatable(PrincipalVariable, {
	__call = function(_, name)
		return PrincipalVariable.new(name)
	end,
	__index = PrincipalVariable,
})

function PrincipalVariable:says(formula)
	return FormulaBinary {
		lhs = self:clone(),
		rhs = formula:clone(CloningType.SUCCEEDING),
		type = FormulaType.SAYS,
	}
end

function PrincipalVariable:controls(formula)
	local says = self:says(formula)
	return says:implication(formula)
end

function PrincipalVariable:speaksFor(other)
	return FormulaBinary {
		lhs = self:clone(),
		rhs = other:clone(),
		type = FormulaType.SPEAKS_FOR,
	}
end

function PrincipalVariable:clone()
	return PrincipalVariable(self.name)
end

function PrincipalVariable:match(other)
	if other.type == PrincipalType.VARIABLE then
		return true, { lhs = {}, rhs = {} }
	elseif other.type == PrincipalType.PNAME then
		return true, {
			lhs = { [self.name] = other },
			rhs = {},
		}
	else
		error("matching error.")
	end
end

function PrincipalVariable:__tostring()
	return string.format("PVar{\"%s\"}", self.name)
end

-------------------------------------------------
-- ReferenceMonitor class.
ReferenceMonitor = {}
ReferenceMonitor.__index = ReferenceMonitor

function ReferenceMonitor.new()
	return setmetatable({
		formulas = {},
	}, ReferenceMonitor)
end

setmetatable(ReferenceMonitor, {
	__call = function()
		return ReferenceMonitor.new()
	end,
})

function ReferenceMonitor:addFormula(formulas)
	for _, formula in ipairs(formulas) do
		table.insert(self.formulas, formula)
	end
end

function ReferenceMonitor:_deriveRecImplication(target)
	if not target.parent then
		local b, _ = self:derive(target.lhs)
		return b
	else

	end
end

function ReferenceMonitor:_deriveResource(target)
	local function find(formula)
		if (target:equals(formula)) then
			return true, formula
		elseif formula.type == FormulaType.IMPLICATION then
			return find(formula.rhs)
		end
		return false, nil
	end
	for _, formula in ipairs(self.formulas) do
		local b, f = find(formula)
		if b then
			local b1 = self:_deriveRecImplication(f.parent)
			if b1 then
				return true, {}
			end
		end
	end
	return false, nil
end

function ReferenceMonitor:_deriveSays(target)
	-- @TODO : SpeaksFor Rule
	local function find(formula)
		local b, caps = target:match(formula)
		if b then
			return true, formula, caps
		elseif formula.type == FormulaType.IMPLICATION then
			return find(formula.rhs)
		end
		return false, nil, nil
	end

	for _, formula in ipairs(self.formulas) do
		local b, f, caps = find(formula)
		if b then
			if f.parent then
				-- @TODO : fill
				self:_deriveRecImplication(f.parent)
			else
				return true, caps.lhs
			end
		end
	end
end

function ReferenceMonitor:derive(target)
	if target.type == FormulaType.LOGICAL_AND then

	elseif target.type == FormulaType.LOGICAL_OR then

	elseif target.type == FormulaType.NEGATION then

	elseif target.type == FormulaType.RESOURCE then
		return self:_deriveResource(target)
	elseif target.type == FormulaType.FACT then

	elseif target.type == FormulaType.IMPLICATION then

	elseif target.type == FormulaType.SPEAKS_FOR then

	elseif target.type == FormulaType.SAYS then
		return self:_deriveSays(target)
	end
end

return {
	Formula            = Formula,
	FormulaBinary      = FormulaBinary,
	FormulaNegation    = FormulaNegation,
	FormulaResource    = FormulaResource,
	FormulaType        = FormulaType,
	Principal          = Principal,
	PrincipalCompound  = PrincipalCompound,
	PrincipalName      = PrincipalName,
	PrincipalType      = PrincipalType,
	PrincipalVariable  = PrincipalVariable,
	ReferenceMonitor   = ReferenceMonitor,

	-- Aliases
	PName              = PrincipalName,
	PVar               = PrincipalVariable,
	Resource           = FormulaResource,
}
