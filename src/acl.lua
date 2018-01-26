--
-- Axcell
-- Copyright (C) 2017 tacigar
--

local util = require "axcell.util"

-- Forward declarations.
local CloningType
local Formula
local FormulaBinary
local FormulaFact
local FormulaNegation
local FormulaPredicate
local FormulaResource
local FormulaType
local Principal
local PrincipalCompound
local PrincipalName
local PrincipalType
local PrincipalVariable
local ReferenceMonitor
local ValueAny
local ValueData
local ValueType

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

CloningType = setmetatable({}, {
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

function Formula:negation()
	return FormulaNegation(self:clone(CloningType.BIDIRECTIONAL))
end
Formula.neg = Formula.negation

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

function FormulaBinary:fill(caps, cloningType, ...)
	cloningType = cloningType or CloningType.BIDIRECTIONAL
	if cloningType == CloningType.BIDIRECTIONAL then
		local args = {...}
		local caller = args[1]
		local newCaller = args[2]
		if caller == nil then
			local lhs = self.lhs:fill(caps, CloningType.SUCCEEDING)
			local rhs = self.rhs:fill(caps, CloningType.SUCCEEDING)
			local f = FormulaBinary {
				lhs = lhs,
				rhs = rhs,
				type = self.type,
			}
			if self.parent then
				self.parent:fill(caps, CloningType.BIDIRECTIONAL, self, f)
			end
			return f
		else
			if caller == self.lhs then
				local rhs = self.rhs:fill(caps, CloningType.SUCCEEDING)
				local f = FormulaBinary {
					lhs = newCaller,
					rhs = rhs,
					type = self.type,
				}
				if self.parent then
					self.parent:fill(caps, CloningType.BIDIRECTIONAL, self, f)
				end
				return f
			elseif caller == self.rhs then
				local lhs = self.lhs:fill(caps, CloningType.SUCCEEDING)
				local f = FormulaBinary {
					lhs = lhs,
					rhs = newCaller,
					type = self.type,
				}
				if self.parent then
					self.parent:fill(caps, CloningType.BIDIRECTIONAL, self, f)
				end
				return f
			else
				error("Filling error.")
			end
		end
	elseif cloningType == CloningType.SUCCEEDING then
		local lhs = self.lhs:fill(caps, CloningType.SUCCEEDING)
		local rhs = self.rhs:fill(caps, CloningType.SUCCEEDING)
		local f = FormulaBinary {
			lhs = lhs,
			rhs = rhs,
			type = self.type,
		}
		return f
	end
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

function FormulaNegation:fill(caps, cloningType, ...)
	if cloningType == CloningType.BIDIRECTIONAL then
		local args = {...}
		local caller = args[1]
		local newCaller = args[2]
		if caller == nil then
			local operand = self.operand:fill(caps, CloningType.SUCCEEDING)
			local f = FormulaNegation(operand)
			if self.parent then
				self.parent:fill(caps, CloningType.BIDIRECTIONAL, self, f)
			end
			return f
		else
			if caller == self.operand then
				local f = FormulaNegation(newCaller)
				if self.parent then
					self.parent:fill(caps, CloningType.BIDIRECTIONAL, self, f)
				end
				return f
			else
				error("Filling error")
			end
		end
	elseif cloningType == CloningType.SUCCEEDING then
		local operand = self.operand:fill(caps, CloningType.SUCCEEDING)
		return FormulaNegation(operand)
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

function FormulaResource:fill(_, cloningType)
	return self:clone(cloningType)
end

function FormulaResource:__tostring()
	return string.format("Res{%s}", self.name)
end

-------------------------------------------------
-- FormulaFact class.
FormulaFact = {}
FormulaFact.__index = FormulaFact

function FormulaFact.new(name)
	return function(params)
		return setmetatable({
			name = name,
			type = FormulaType.FACT,
			principal = params[1],
			data = params[2],
		}, FormulaFact)
	end
end

setmetatable(FormulaFact, {
	__call = function(_, name)
		return FormulaFact.new(name)
	end,
	__index = Formula,
})

function FormulaFact:clone(cloningType)
	if cloningType == CloningType.BIDIRECTIONAL then
		local f = FormulaFact(self.name){
			self.principal,
			self.data,
		}
		if self.parent then
			self.parent:clone(CloningType.BIDIRECTIONAL, self, f)
		end
		return f
	elseif cloningType == CloningType.SUCCEEDING then
		return FormulaFact(self.name){
			self.principal,
			self.data,
		}
	end
end

function FormulaFact:match(other)
	if self.type ~= other.type or self.name ~= other.name then
		return false, nil
	end
	local pb, pcaps = self.principal:match(other.principal)
	if not pb then
		return false, nil
	end
	local db, dcaps = self.data:match(other.data)
	if not db then
		return false, nil
	end
	return true, {
		lhs = util.table.merge(pcaps.lhs, dcaps.lhs),
		rhs = util.table.merge(pcaps.rhs, dcaps.rhs),
	}
end

function FormulaFact:fill(caps, cloningType)
	cloningType = cloningType or CloningType.BIDIRECTIONAL
	if cloningType == CloningType.BIDIRECTIONAL then
		local f = FormulaFact(self.name){
			self.principal:fill(caps),
			self.data:fill(caps),
		}
		if self.parent then
			self.parent:fill(caps, CloningType.BIDIRECTIONAL, self, f)
		end
		return f
	elseif cloningType == CloningType.SUCCEEDING then
		return FormulaFact(self.name){
			self.principal:fill(caps),
			self.data:fill(caps),
		}
	end
end

function FormulaFact:__tostring()
	return string.format("Fact\"%s\"{%s, %s}", self.name, tostring(self.principal), tostring(self.data))
end

-------------------------------------------------
-- FormulaPredicate class.
FormulaPredicate = {}
FormulaPredicate.__index = FormulaPredicate

function FormulaPredicate.new(pred)
	return setmetatable({}, {
		__call = function(_, arg)
			return setmetatable({
				pred = pred,
				arg = arg,
				type = FormulaType.PREDICATE,
			}, {
				__call = function(self) -- invoke pred function
					if self.arg.type == ValueType.ANY then
						return false
					elseif self.arg.type == ValueType.DATA then
						return self.pred(self.arg.data)
					end
				end,
				__index = FormulaPredicate,
				__tostring = function(self)
					return string.format("Pred{%s(%s)}", tostring(self.pred), tostring(self.arg))
				end,
			})
		end,
	})
end

setmetatable(FormulaPredicate, {
	__call = function(_, pred)
		return FormulaPredicate.new(pred)
	end,
	__index = Formula,
})

function FormulaPredicate:clone(cloningType)
	if cloningType == CloningType.BIDIRECTIONAL then
		local f = FormulaPredicate(self.pred)(self.arg)
		if self.parent then
			self.parent:clone(CloningType.BIDIRECTIONAL, self, f)
		end
		return f
	elseif cloningType == CloningType.SUCCEEDING then
		return FormulaPredicate(self.pred)(self.arg)
	end
end

function FormulaPredicate:fill(caps, cloningType)
	if cloningType == CloningType.BIDIRECTIONAL then
		local arg = self.arg:fill(caps)
		local f = FormulaPredicate(self.pred)(arg)
		if self.parent then
			self.parent:fill(caps, CloningType.BIDIRECTIONAL, self, f)
		end
		return f
	elseif cloningType == CloningType.SUCCEEDING then
		local arg = self.arg:fill(caps)
		return FormulaPredicate(self.pred)(arg)
	end
end

-------------------------------------------------
-- ValueType enum.
local _ValueType = {
	DATA = 1,
	ANY  = 2,
}

ValueType = setmetatable({}, {
   __index = function(_, key)
	   if _ValueType[key] then
		   return _ValueType[key]
	   end
	   error(string.format("ValueType don't have such a value: %s", key))
   end,
   __newindex = function(_, _, _)
	   error("Attempt to modify read-only table: ValueType")
   end,
   __metatable = false,
})
-------------------------------------------------
-- ValueData class.
ValueData = {}
ValueData.__index = ValueData

function ValueData.new(data)
	return setmetatable({
		data = data,
		type = ValueType.DATA,
	}, ValueData)
end

setmetatable(ValueData, {
	__call = function(_, data)
		return ValueData.new(data)
	end,
})

function ValueData:match(other)
	if other.type == ValueType.DATA then
		if util.table.deepEquals(self.data, other.data) then
			return true, { lhs = {}, rhs = {} }
		else
			return false, nil
		end
	else -- ValueType.ANY
		return true, {
			lhs = {},
			rhs = { [other.name] = self },
		}
	end
end

function ValueData:fill()
	return self
end

function ValueData:__tostring()
	return string.format("Data{%s}", tostring(self.data))
end

-------------------------------------------------
-- Any class.
ValueAny = {}
ValueAny.__index = ValueAny

function ValueAny.new(name)
	return setmetatable({
		name = name,
		type = ValueType.ANY,
	}, ValueAny)
end

setmetatable(ValueAny, {
	__call = function(_, name)
		return ValueAny.new(name)
	end,
})

function ValueAny:match(other)
	if other.type == ValueType.ANY then
		return true, { lhs = {}, rhs = {} }
	else
		return true, {
			lhs = { [self.name] = other },
			rhs = {},
		}
	end
end

function ValueAny:fill(caps)
	if caps[self.name] then
		return caps[self.name]
	else
		return self
	end
end

function ValueAny:__tostring()
	return string.format("Any\"%s\"", self.name)
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

function PrincipalName:equals(other)
	if other.type ~= PrincipalType.PNAME then
		return false
	end
	return self.name == other.name
end

function PrincipalName:match(other)
	if other.type == PrincipalType.PNAME then
		if self.name == other.name then
			return true, { lhs = {}, rhs = {} }
		else
			return false, nil
		end
	elseif other.type == PrincipalType.VARIABLE then
		return true, {
			lhs = {},
			rhs = { [other.name] = self },
		}
	else
		error("matching error.")
	end
end

function PrincipalName:fill()
	return self:clone()
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

function PrincipalVariable:fill(caps)
	if caps[self.name] then
		return caps[self.name]:clone()
	else
		return self:clone()
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
		return self:derive(target.lhs)
	else
		local res, capss = false, {}
		local b1, capss1 = self:derive(target.lhs)
		if not b1 then
			return false, nil
		end
		if #capss1 > 0 then
			for _, caps1 in ipairs(capss1) do
				local f = target:fill(caps1)
				local b2, capss2 = self:_deriveRecImplication(f.parent)
				if b2 then
					res = true
					if #capss2 > 0 then
						for _, caps2 in ipairs(capss2) do
							table.insert(capss, util.table.merge(caps1, caps2))
						end
					else
						table.insert(capss, caps1)
					end
				end
			end
		else
			local f = target:clone()
			local b2, capss2 = self:_deriveRecImplication(f.parent)
			if b2 then
				res = true
				if #capss2 > 0 then
					for _, caps2 in ipairs(capss2) do
						table.insert(capss, caps2)
					end
				end
			end
		end
		if res then
			return true, capss
		else
			return false, nil
		end
	end
end

function ReferenceMonitor:_deriveLogicalAnd(target)
	local res, capss = false, {}
	local lb, lcapss = self:derive(target.lhs)
	if not lb then
		return false, nil
	else
		if #lcapss > 0 then
			for _, lcaps in ipairs(lcapss) do
				local f = target:fill(lcaps)
				local rb, rcapss = self:derive(f.rhs)
				if rb then
					res = true
					if #rcapss > 0 then
						for _, rcaps in ipairs(rcapss) do
							table.insert(capss, util.table.merge(lcaps, rcaps))
						end
					else
						table.insert(capss, lcaps)
					end
				end
			end
		else
			local f = target:clone()
			local rb, rcapss = self:derive(f.rhs)
			if rb then
				res = true
				if #rcapss > 0 then
					for _, rcaps in ipairs(rcapss) do
						table.insert(capss, rcaps)
					end
				end
			end
		end
	end
	if res then
		return true, capss
	else
		return false, nil
	end
end

function ReferenceMonitor:_deriveLogicalOr(target)
	local lb, lcapss = self:derive(target.lhs)
	if lb then
		return true, lcapss
	else
		local rb, rcapss = self:derive(target.rhs)
		if rb then
			return true, rcapss
		end
	end
	return false, nil
end

function ReferenceMonitor:_deriveNegation(target)
	local b, _ = self:derive(target.operand)
	if not b then
		return true, {}
	else
		return false, nil
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
			local b1, _ = self:_deriveRecImplication(f.parent)
			if b1 then
				return true, {}
			end
		end
	end
	return false, nil
end

function ReferenceMonitor:_deriveFact(target)
	local function find(formula)
		local b, caps = target:match(formula)
		if b then
			return true, formula, caps
		elseif formula.type == FormulaType.IMPLICATION then
			return find(formula.rhs)
		end
		return false, nil, nil
	end

	local res, capss = false, {}
	for _, formula in ipairs(self.formulas) do
		local b, f, caps = find(formula)
		if b then
			if f.parent then
				f = f:fill(caps.rhs)
				local b1, capss1 = self:_deriveRecImplication(f.parent)
				if b1 then -- derivable
					res = true
					if #capss1 > 0 then
						for _, caps1 in ipairs(capss1) do
							local f2 = f:fill(caps1)
							local _, caps2 = f2:match(target)
							table.insert(capss, caps2.rhs)
						end
					else
						table.insert(capss, caps.lhs)
					end
				end
			else -- Perfect matching
				res = true
				table.insert(capss, caps.lhs)
			end
		end
	end
	if res then
		return true, capss
	else
		return false, nil
	end
end

function ReferenceMonitor._derivePredicate(_, target) -- not use `self`
	if target() then
		return true, {}
	else
		return false, nil
	end
end

function ReferenceMonitor:_deriveSpeaksFor(target)
	local function find(formula)
		local b, caps = target:match(formula)
		if b then
			return true, formula, caps
		elseif formula.type == FormulaType.IMPLICATION then
			return find(formula.rhs)
		end
		return false, nil, nil
	end

	if target.lhs.type == PrincipalType.PNAME and target.rhs.type == PrincipalType.PNAME then
		-- Idempotency of SpeaksFor Rule.
		if target.lhs:equals(target.rhs) then
			return true, {}
		end

		-- Transitivity of SpeaksFor Rule.
		local b, capss = self:derive(target.lhs:speaksFor(PrincipalVariable"__X"))
		if b then
			for _, caps in ipairs(capss) do
				if not caps["__X"]:equals(target.lhs) then -- Avoid unlimited loops.
					local b2, _ = self:derive(caps["__X"]:speaksFor(target.rhs))
					if b2 then
						return true, {}
					end
				end
			end
		end
		return false, nil
	elseif target.lhs.type == PrincipalType.PNAME and target.rhs.type == PrincipalType.VARIABLE then
		local capss = {}
		table.insert(capss, { [target.rhs.name] = target.lhs })
		for _, formula in ipairs(self.formulas) do
			local b, f, caps = find(formula)
			if b then
				f = f:fill(caps.rhs)
				if f.parent then
					local b1, capss1 = self:_deriveRecImplication(f.parent)
					if b1 then -- derivable
						if #capss1 > 0 then
							for _, caps1 in ipairs(capss1) do
								local f1 = f:fill(caps1)
								local _, caps2 = f1:match(target)
								table.insert(capss, caps2.rhs)
							end
						else
							table.insert(capss, caps.lhs)
						end
						-- For Transitivity
						local b2, capss2 = self:derive(f.rhs:speaksFor(PrincipalVariable"__X"))
						if b2 then
							for _, caps2 in ipairs(capss2) do
								table.insert(capss, { [target.rhs.name] = caps2["__X"] })
							end
						end
					end
				else -- Perfect matching.
					table.insert(capss, caps.lhs)
					-- For Transitivity
					local b2, capss2 = self:derive(f.rhs:speaksFor(PrincipalVariable"__X"))
					if b2 then
						for _, caps2 in ipairs(capss2) do
							table.insert(capss, { [target.rhs.name] = caps2["__X"] })
						end
					end
				end

			end
		end
		return true, capss
	elseif target.lhs.type == PrincipalType.VARIABLE and target.rhs.type == PrincipalType.PNAME then
		local capss = {}
		table.insert(capss, { [target.lhs.name] = target.rhs })
		for _, formula in ipairs(self.formulas) do
			local b, f, caps = find(formula)
			if b then
				f = f:fill(caps.rhs)
				if f.parent then
					local b1, capss1 = self:_deriveRecImplication(f.parent)
					if b1 then
						if #capss1 > 0 then
							for _, caps1 in ipairs(capss1) do
								local f1 = f:fill(caps1)
								local _, caps2 = f1:match(target)
								table.insert(capss, caps2.rhs)
							end
						else
							table.insert(capss, caps.lhs)
						end
						-- For Transitivity
						local b2, capss2 = self:derive(PrincipalVariable"__X":speaksFor(f.lhs))
						if b2 then
							for _, caps2 in ipairs(capss2) do
								table.insert(capss, { [target.lhs.name] = caps2["__X"] })
							end
						end
					end
				else -- Perfect matching
					table.insert(capss, caps.lhs)
					-- For Transitivity
					local b2, capss2 = self:derive(PrincipalVariable"__X":speaksFor(f.lhs))
					if b2 then
						for _, caps2 in ipairs(capss2) do
							table.insert(capss, { [target.lhs.name] = caps2["__X"] })
						end
					end
				end
			end
		end
		return true, capss
	else
		local res, capss = false, {}
		for _, formula in ipairs(self.formulas) do
			local b, f, caps = find(formula)
			if b then
				if f.parent then
					return self:_deriveRecImplication(f.parent)
				else -- Perfect matching
					res = true
					table.insert(capss, caps.lhs)
				end
			end
		end
		if res then
			return true, capss
		else
			return false, nil
		end
	end
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

	local res, capss = false, {}
	for _, formula in ipairs(self.formulas) do
		local b, f, caps = find(formula)
		if b then
			if f.parent then
				-- @TODO : fill
				return self:_deriveRecImplication(f.parent)
			else -- Perfect matching
				res = true
				table.insert(capss, caps.lhs)
			end
		end
	end
	if res then
		return true, capss
	else
		return false, nil
	end
end

function ReferenceMonitor:derive(target)
	local function unique(capss)
		local deletes = {}
		if #capss <= 1 then
			return
		end
		for i = 1, #capss do
			for j = i + 1, #capss do
				for k, v in pairs(capss[i]) do
					if capss[j][k] and (not v:equals(capss[j][k])) then
						goto CONTINUE
					end
				end
				for k, v in pairs(capss[j]) do
					if capss[i][k] and (not v:equals(capss[i][k])) then
						goto CONTINUE
					end
				end
				table.insert(deletes, j)
				::CONTINUE::
			end
		end
		if #deletes > 0 then
			for i = #deletes, 1, -1 do
				table.remove(capss, deletes[i])
			end
		end
	end

	local b, capss
	if target.type == FormulaType.LOGICAL_AND then
		b, capss = self:_deriveLogicalAnd(target)
	elseif target.type == FormulaType.LOGICAL_OR then
		b, capss = self:_deriveLogicalOr(target)
	elseif target.type == FormulaType.NEGATION then
		b, capss = self:_deriveNegation(target)
	elseif target.type == FormulaType.RESOURCE then
		b, capss = self:_deriveResource(target)
	elseif target.type == FormulaType.FACT then
		b, capss = self:_deriveFact(target)
	elseif target.type == FormulaType.PREDICATE then
		b, capss = self:_derivePredicate(target)
	elseif target.type == FormulaType.IMPLICATION then

	elseif target.type == FormulaType.SPEAKS_FOR then
		b, capss = self:_deriveSpeaksFor(target)
	elseif target.type == FormulaType.SAYS then
		b, capss = self:_deriveSays(target)
	end
	if b then
		unique(capss)
		return true, capss
	else
		return false, nil
	end
end

return {
	CloningType        = CloningType,
	Formula            = Formula,
	FormulaBinary      = FormulaBinary,
	FormulaFact        = FormulaFact,
	FormulaNegation    = FormulaNegation,
	FormulaPredicate   = FormulaPredicate,
	FormulaResource    = FormulaResource,
	FormulaType        = FormulaType,
	Principal          = Principal,
	PrincipalCompound  = PrincipalCompound,
	PrincipalName      = PrincipalName,
	PrincipalType      = PrincipalType,
	PrincipalVariable  = PrincipalVariable,
	ReferenceMonitor   = ReferenceMonitor,
	ValueAny           = ValueAny,
	ValueData          = ValueData,
	-- Aliases
	Any                = ValueAny,
	Data               = ValueData,
	Fact               = FormulaFact,
	PName              = PrincipalName,
	Predicate          = FormulaPredicate,
	PVar               = PrincipalVariable,
	Resource           = FormulaResource,
}
