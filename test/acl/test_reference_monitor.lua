--
-- Axcell
-- Copyright (C) 2018 tacigar
--

local acl = require "axcell.acl"
local unit = require "luaunit"

local function contains(capss, p)
	for _, caps in ipairs(capss) do
		if caps.Cx:equals(p) then
			return true
		end
	end
	return false
end

TestReferenceMonitor = {}

function TestReferenceMonitor:testDerive_Controls_1()
	local rm = acl.ReferenceMonitor()
	rm:addFormula {
		acl.PName"C1":controls(acl.Resource"R");
		acl.PName"C1":says(acl.Resource"R");
		acl.PName"C1":says(acl.Resource"S");
		acl.PName"C2":controls(acl.Resource"S");
	}
	local b
	b = rm:derive(acl.Resource"R")
	unit.assertTrue(b)
	b = rm:derive(acl.Resource"S")
	unit.assertFalse(b)
end

function TestReferenceMonitor:testDerive_Controls_2()
	local rm = acl.ReferenceMonitor()
	rm:addFormula {
		acl.PVar"Cx":controls(acl.Resource"R");
		acl.PVar"Cx":controls(acl.Resource"S");
		acl.PVar"Cx":controls(acl.Resource"T");
		acl.PName"C1":says(acl.Resource"R");
		acl.PName"C2":says(acl.Resource"S");
	}
	local b
	b = rm:derive(acl.Resource"R")
	unit.assertTrue(b)
	b = rm:derive(acl.Resource"S")
	unit.assertTrue(b)
	b = rm:derive(acl.Resource"T")
	unit.assertFalse(b)
end

function TestReferenceMonitor:testDerive_TransitivitySpeaksFor_1()
	local rm = acl.ReferenceMonitor()
	rm:addFormula {
		acl.PName"C1":speaksFor(acl.PName"C2");
		acl.PName"C2":speaksFor(acl.PName"C3");
		acl.PName"C3":speaksFor(acl.PName"C4");
		acl.PName"C1":speaksFor(acl.PName"C5");
	}
	local b
	b = rm:derive(acl.PName"C1":speaksFor(acl.PName"C2"))
	unit.assertTrue(b)
	b = rm:derive(acl.PName"C1":speaksFor(acl.PName"C3"))
	unit.assertTrue(b)
	b = rm:derive(acl.PName"C2":speaksFor(acl.PName"C4"))
	unit.assertTrue(b)
	b = rm:derive(acl.PName"C2":speaksFor(acl.PName"C5"))
	unit.assertFalse(b)
end

function TestReferenceMonitor:testDerive_TransitivitySpeaksFor_2()
	local rm = acl.ReferenceMonitor()
	rm:addFormula {
		acl.PName"C1":speaksFor(acl.PName"C2");
		acl.PName"C2":speaksFor(acl.PName"C3");
		acl.PName"C3":speaksFor(acl.PName"C4");
		acl.PName"C1":speaksFor(acl.PName"C5");
	}
	local b, capss

	b, capss = rm:derive(acl.PName"C1":speaksFor(acl.PVar"Cx"))
	unit.assertTrue(b)
	unit.assertEquals(#capss, 5) -- C1-C5
	unit.assertTrue(contains(capss, acl.PName"C2"))
	unit.assertTrue(contains(capss, acl.PName"C3"))
	unit.assertTrue(contains(capss, acl.PName"C4"))
	unit.assertTrue(contains(capss, acl.PName"C5"))

	b, capss = rm:derive(acl.PName"C2":speaksFor(acl.PVar"Cx"))
	unit.assertTrue(b)
	unit.assertEquals(#capss, 3) -- C2-C4
	unit.assertTrue(contains(capss, acl.PName"C2"))
	unit.assertTrue(contains(capss, acl.PName"C3"))
	unit.assertTrue(contains(capss, acl.PName"C4"))

	b, capss = rm:derive(acl.PName"C3":speaksFor(acl.PVar"Cx"))
	unit.assertTrue(b)
	unit.assertEquals(#capss, 2) -- C3-C4
	unit.assertTrue(contains(capss, acl.PName"C3"))
	unit.assertTrue(contains(capss, acl.PName"C4"))

	b, capss = rm:derive(acl.PVar"Cx":speaksFor(acl.PName"C2"))
	unit.assertTrue(b)
	unit.assertEquals(#capss, 2) -- C1-C2
	unit.assertTrue(contains(capss, acl.PName"C1"))
	unit.assertTrue(contains(capss, acl.PName"C2"))
end

function TestReferenceMonitor:testDerive_Negation_1()
	local rm = acl.ReferenceMonitor()
	rm:addFormula {
		((acl.PName"C1":says(acl.Resource"R")):neg()):imp(acl.Resource"R")
	}
	local b, _ = rm:derive(acl.Resource"R")
	unit.assertTrue(b)
end

function TestReferenceMonitor:testDerive_Fact_1()
	local rm = acl.ReferenceMonitor()
	rm:addFormula {
		acl.PName"C1":says(acl.Fact"At"{acl.PName"C1", acl.Data{x = 4, y = 7}});
		acl.PVar"Cx":controls(acl.Fact"At"{acl.PVar"Cx", acl.Any"L"});
	}
	local b, capss = rm:derive(acl.Fact"At"{acl.PName"C1", acl.Any"L"})
	unit.assertTrue(b)
	unit.assertEquals(capss[1]["L"].data.x, 4)
	unit.assertEquals(capss[1]["L"].data.y, 7)
end

function TestReferenceMonitor:testDerive_Fact_2()
	local rm = acl.ReferenceMonitor()
	rm:addFormula {
		((acl.PVar"Cx":says(acl.Resource"R")):land(acl.Fact"At"{acl.PVar"Cx", acl.Any"L"}))
			:imp(acl.Resource "R");
		acl.PName"C1":says(acl.Resource"R");
		acl.Fact"At"{acl.PName"C1", acl.Data{x = 4, y = 7}};
	}
	local b, _ = rm:derive(acl.Resource "R")
	unit.assertTrue(b)
end

function TestReferenceMonitor:testDerive_Predicate_1()
	local isAlice = acl.Predicate(function(userInfo)
		return userInfo.name == "Alice" and userInfo.pass == "ECILA"
	end)
	local rm = acl.ReferenceMonitor()
	rm:addFormula {
		(acl.Fact"At"{acl.PName"Alice", acl.Any"U"}:land(isAlice(acl.Any"U")))
			:imp(acl.Resource"R");
		(acl.Fact"At"{acl.PName"Alice", acl.Data{name = "Alice", pass = "ECILA"}});
	}
	local b, _ = rm:derive(acl.Resource"R")
	unit.assertTrue(b)
end

function TestReferenceMonitor:testDerive_Application1()
	local isAuthUser = acl.Predicate(function(userInfo)
		return userInfo.name == "John" and userInfo.pass == "nhoj"
	end)
	local rm = acl.ReferenceMonitor()
	rm:addFormula {
		-- C1 says (UserInfo(C1, <John, nhoj>))
		acl.PName"C1":says(acl.Fact"UserInfo"{acl.PName"C1", acl.Data{name = "John", pass = "nhoj"}});
		-- C2 says (UserInfo(C2, <Alice, ecila>))
		acl.PName"C2":says(acl.Fact"UserInfo"{acl.PName"C2", acl.Data{name = "Alice", pass = "ecila"}});
		-- forall Cx, U, Cx controls (UserInfo<Cx, U>)
		acl.PVar"Cx":controls(acl.Fact"UserInfo"{acl.PVar"Cx", acl.Any"U"});
		-- forall Cx, U, UserInfo<Cx, U> land (isAuthUser(U)) imp (Cx => Cauth)
		(acl.Fact"UserInfo"{acl.PVar"Cx", acl.Any"U"}:land(isAuthUser(acl.Any"U")))
			:imp(acl.PVar"Cx":speaksFor(acl.PName"Cauth"));
		-- forall Cx, U, UserInfo<Cx, U> land (neg isAuthUser(U)) imp (Cx => Cnorm)
		(acl.Fact"UserInfo"{acl.PVar"Cx", acl.Any"U"}:land(isAuthUser(acl.Any"U"):neg()))
			:imp(acl.PVar"Cx":speaksFor(acl.PName"Cnorm"));
	}
	local b, capss
	b, capss = rm:derive(acl.PName"C1":speaksFor(acl.PVar"Cx"))
	unit.assertTrue(b)
	unit.assertTrue(contains(capss, acl.PName"C1"))
	unit.assertTrue(contains(capss, acl.PName"Cauth"))
	b, capss = rm:derive(acl.PName"C2":speaksFor(acl.PVar"Cx"))
	unit.assertTrue(b)
	unit.assertTrue(contains(capss, acl.PName"C2"))
	unit.assertTrue(contains(capss, acl.PName"Cnorm"))
end

os.exit(unit.LuaUnit.run("-v"))
