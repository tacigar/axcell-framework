/*
** Axcell
** Copyright (C) 2017 tacigar
*/

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include <string.h>
#include <uuid/uuid.h>

#define AXCELL_UUID_CLASS "axcell.uuid.uuid"

typedef struct UUID
{
	uuid_t m_uuid;
} UUID;

static UUID *newUUID(lua_State *L)
{
	UUID *obj = (UUID *)lua_newuserdata(L, sizeof(UUID));
	luaL_getmetatable(L, AXCELL_UUID_CLASS);
	lua_setmetatable(L, -2);
	return obj;
}

static int generate(lua_State *L)
{
	uuid_t id;
	UUID *obj;

	uuid_generate(id);
	obj = newUUID(L);
	uuid_copy(obj->m_uuid, id);

	return 1;
}

static int clone(lua_State *L)
{
	uuid_t id;
	UUID *obj;

	obj = luaL_checkudata(L, 1, AXCELL_UUID_CLASS);
	uuid_copy(id, obj->m_uuid);
	obj = newUUID(L);
	uuid_copy(obj->m_uuid, id);

	return 1;
}

static int unparse(lua_State *L)
{
	UUID *obj;
	uuid_string_t str;

	obj = luaL_checkudata(L, 1, AXCELL_UUID_CLASS);
	if (lua_isstring(L, 2) == 1) {
		const char *op = lua_tostring(L, 2);
		if (strcmp(op, "upper")) {
			uuid_unparse_upper(obj->m_uuid, str);
		} else if(strcmp(op, "lower")) {
			uuid_unparse_lower(obj->m_uuid, str);
		} else {
			uuid_unparse(obj->m_uuid, str);
		}
	} else {
		uuid_unparse(obj->m_uuid, str);
	}

	lua_pushstring(L, (const char *)str);
	return 1;
}

static int compare(lua_State *L)
{
	UUID *lhs;
	UUID *rhs;

	lhs = luaL_checkudata(L, 1, AXCELL_UUID_CLASS);
	rhs = luaL_checkudata(L, 2, AXCELL_UUID_CLASS);

	lua_pushboolean(L, uuid_compare(lhs->m_uuid, rhs->m_uuid) == 0);
	return 1;
}

static int parse(lua_State *L)
{
	uuid_t id;
	UUID *obj;

	const char *str = luaL_checkstring(L, 1);
	uuid_parse(str, id);

	obj = newUUID(L);
	uuid_copy(obj->m_uuid, id);

	return 1;
}

static int clear(lua_State *L)
{
	UUID *obj;
	obj = luaL_checkudata(L, 1, AXCELL_UUID_CLASS);
	uuid_clear(obj->m_uuid);
	return 0;
}

static int is_null(lua_State *L)
{
	UUID *obj;
	obj = luaL_checkudata(L, 1, AXCELL_UUID_CLASS);
	lua_pushboolean(L, uuid_is_null(obj->m_uuid));
	return 1;
}

static const luaL_Reg methods[] = {
	{ "clone",    clone   },
	{ "unparse",  unparse },
	{ "clear",    clear   },
	{ "is_null",  is_null },
	{ "compare",  compare },
	{ "__eq",     compare },
	{ NULL, NULL }
};

static void register_methods(lua_State *L)
{
	luaL_newmetatable(L, AXCELL_UUID_CLASS);
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");
	luaL_setfuncs(L, methods, 0);
	lua_pop(L, 1);
}

static const luaL_Reg functions[] = {
	{ "generate", generate },
    { "parse",    parse    },
	{ NULL, NULL }
};

LUALIB_API int luaopen_axcell_uuid(lua_State *L)
{
	register_methods(L);
	luaL_newlib(L, functions);
	return 1;
}
