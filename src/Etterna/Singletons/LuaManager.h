#ifndef LUA_MANAGER_H
#define LUA_MANAGER_H

struct lua_State;
using Lua = struct lua_State;
using RegisterWithLuaFn = void (*)(struct lua_State*);
class RageMutex;
class XNode;
class LuaReference;

#include "lua.hpp"

// For Dialog::Result
#include "RageUtil/Utils/RageUtil.h"
#include "arch/Dialog/Dialog.h"

class LuaManager
{
  public:
	// Every Actor should register its class at program initialization.
	static void Register(RegisterWithLuaFn pfn);

	LuaManager();
	~LuaManager();

	auto Get() -> Lua*;
	void Release(Lua*& p);

	/* Explicitly lock and unlock Lua access. This is done automatically by
	 * Get() and Release(). */
	void YieldLua();
	void UnyieldLua();

	// Register all subscribing types.
	// There's no harm in registering when already registered.
	void RegisterTypes();

	void SetGlobal(const std::string& sName, int val);
	void SetGlobal(const std::string& sName, float val);
	void SetGlobal(const std::string& sName, const std::string& val);
	void UnsetGlobal(const std::string& sName);

  private:
	lua_State* m_pLuaMain;
	// Swallow up warnings. If they must be used, define them.
	auto operator=(const LuaManager& rhs) -> LuaManager&;
	LuaManager(const LuaManager& rhs);
};

extern LuaManager* LUA;

/** @brief Utilities for working with Lua. */
namespace LuaHelpers {
/* Load the given script with the given name. On success, the resulting
 * chunk will be on the stack. On error, the error is stored in sError
 * and the stack is unchanged. */
auto
LoadScript(Lua* L,
		   const std::string& sScript,
		   const std::string& sName,
		   std::string& sError) -> bool;

/* Report the error three ways:  Broadcast message, Warn, and Dialog. */
/* If UseAbort is true, reports the error through Dialog::AbortRetryIgnore
	 and returns the result. */
/* If UseAbort is false, reports the error through Dialog::OK and returns
	 Dialog::ok. */
auto
ReportScriptError(std::string const& Error,
				  std::string ErrorType = "LUA_ERROR",
				  bool UseAbort = false) -> Dialog::Result;
// Just the broadcast message part, for things that need to do the rest
// differently.
void
ScriptErrorMessage(std::string const& Error);

/** @brief A convenience method to use when replacing uses of LOG->Warn. */
template<typename... Args>
void
ReportScriptErrorFmt(std::string const& msg, Args const&... args)
{
	std::string result = ssprintf(msg.c_str(), args...);
	ReportScriptError(result);
}

/* Run the function with arguments at the top of the stack, with the given
 * number of arguments. The specified number of return values are left on
 * the Lua stack. On error, nils are left on the stack, sError is set and
 * false is returned.
 * If ReportError is true, Error should contain the string to prepend
 * when reporting.  The error is reported through LOG->Warn and
 * SCREENMAN->SystemMessage.
 */
auto
RunScriptOnStack(Lua* L,
				 std::string& Error,
				 int Args = 0,
				 int ReturnValues = 0,
				 bool ReportError = false,
				 bool blank_env = false) -> bool;

/* LoadScript the given script, and RunScriptOnStack it.
 * iArgs arguments are at the top of the stack. */
auto
RunScript(Lua* L,
		  const std::string& Script,
		  const std::string& Name,
		  std::string& Error,
		  int Args = 0,
		  int ReturnValues = 0,
		  bool ReportError = false,
		  bool blank_env = false) -> bool;

/* Run the given expression, returning a single value, and leave the return
 * value on the stack.  On error, push nil. */
auto
RunExpression(Lua* L,
			  const std::string& sExpression,
			  const std::string& sName = "",
			  bool blank_env = false) -> bool;

auto
RunScriptFile(const std::string& sFile, bool blank_env = false) -> bool;

auto
run_script_file_in_state(lua_State* L,
						 std::string const& filename,
						 int return_values,
						 bool blank_env) -> bool;
auto
string_can_be_lua_identifier(lua_State* L, std::string const& str) -> bool;
void
push_lua_escaped_string(lua_State* L, std::string const& str);
// save_lua_table_to_file will only save bools, strings, and numbers.
// Nothing else in the lua table will be saved.
void
save_lua_table_to_file(lua_State* L,
					   int table_index,
					   std::string const& filename);

/* Create a Lua array (a table with indices starting at 1) of the given vector,
 * and push it on the stack. */
void
CreateTableFromArrayB(Lua* L, const std::vector<bool>& aIn);

// Create a Lua table with contents set from this XNode, then push it on the
// stack.
void
CreateTableFromXNode(Lua* L, const XNode* pNode);

/* Recursively copy elements from the table at stack element -2 into the
 * table at stack -1. Pop both elements from the stack. */
void
DeepCopy(lua_State* L);

// Read the table at the top of the stack back into a vector.
void
ReadArrayFromTableB(Lua* L, std::vector<bool>& aOut);

void
rec_print_table(lua_State* L,
				std::string const& name,
				std::string const& indent);

void
ParseCommandList(lua_State* L,
				 const std::string& sCommands,
				 const std::string& sName,
				 bool bLegacy);

auto
GetLuaInformation() -> XNode*;

/* Pops the last iArgs arguments from the stack, and return a function that
 * returns those values. */
void
PushValueFunc(lua_State* L, int iArgs);

template<class T>
void
Push(lua_State* L, const T& Object);

template<class T>
auto
FromStack(lua_State* L, T& Object, int iOffset) -> bool;

// Not using a template for the c style string: found it tricky to use.
auto
FromStack(lua_State* L, char const* Object, int iOffset) -> bool;

template<class T>
auto
Pop(lua_State* L, T& val) -> bool
{
	bool bRet = LuaHelpers::FromStack(L, val, -1);
	lua_pop(L, 1);
	return bRet;
}

template<class T>
void
ReadArrayFromTable(std::vector<T>& aOut, lua_State* L)
{
	luaL_checktype(L, -1, LUA_TTABLE);

	int i = 0;
	while (lua_rawgeti(L, -1, ++i), !lua_isnil(L, -1)) {
		T value = T();
		LuaHelpers::Pop(L, value);
		aOut.push_back(value);
	}
	lua_pop(L, 1); // pop nil
}
template<class T>
void
CreateTableFromArray(const std::vector<T>& aIn, lua_State* L)
{
	lua_newtable(L);
	for (unsigned i = 0; i < aIn.size(); ++i) {
		LuaHelpers::Push(L, aIn[i]);
		lua_rawseti(L, -2, i + 1);
	}
}

auto
TypeError(Lua* L, int narg, std::string const& tname) -> int;
inline auto
AbsIndex(Lua* L, int i) -> int
{
	if (i > 0 || i <= LUA_REGISTRYINDEX) {
		return i;
	}
	return lua_gettop(L) + i + 1;
}
} // namespace LuaHelpers

class LuaThreadVariable
{
  public:
	LuaThreadVariable(const std::string& sName, const std::string& sValue);
	LuaThreadVariable(const std::string& sName, const LuaReference& Value);
	LuaThreadVariable(lua_State* L); // name and value are on stack
	~LuaThreadVariable();
	static void GetThreadVariable(lua_State* L);

  private:
	LuaThreadVariable(const LuaThreadVariable& cpy); // not defined

	void SetFromStack(lua_State* L);
	auto AdjustCount(lua_State* L, int iAdd) -> int;
	static auto PushThreadTable(lua_State* L, bool bCreate) -> bool;
	static auto GetCurrentThreadIDString() -> std::string;

	LuaReference* m_Name;
	LuaReference* m_pOldValue;

	// Swallow up warnings. If they must be used, define them.
	auto operator=(const LuaThreadVariable& rhs) -> LuaThreadVariable&;
};

/**
 * @brief Iterate over all elements in the table.
 *
 * For safety reasons, the key is pushed onto the stack and can be read (safely)
 * as a string and popped or altered in any way. Stack management is handled
 * automatically. That is, you need not remove all stack elements above the key.
 * Once the loop exits normally, the top of the stack will be where it was
 * before. If you break out of the loop early, you need to handle that
 * explicitly. */
#define FOREACH_LUATABLE(L, index)                                             \
                                                                               \
	for (const int SM_UNIQUE_NAME(tab) = LuaHelpers::AbsIndex(L, index),       \
				   SM_UNIQUE_NAME(top) = (lua_pushnil(L), lua_gettop(L));      \
		 lua_next(L, SM_UNIQUE_NAME(tab)) && (lua_pushvalue(L, -2), true);     \
		 lua_settop(L, SM_UNIQUE_NAME(top)))

/** @brief Iterate over the array elements of a table. */
#define FOREACH_LUATABLEI(L, index, i)                                         \
	for (int SM_UNIQUE_NAME(tab) = LuaHelpers::AbsIndex(L, index),             \
			 SM_UNIQUE_NAME(top) = lua_gettop(L),                              \
			 (i) = 1;                                                          \
		 lua_rawgeti(L, SM_UNIQUE_NAME(tab), i),                               \
			 lua_isnil(L, -1)                                                  \
			   ? (lua_pop(L, 1), false)                                        \
			   : (true); /* if nil, pop the nil and stop traversal */          \
		 lua_settop(L, SM_UNIQUE_NAME(top)), ++(i))

struct RegisterLuaFunction
{
	RegisterLuaFunction(RegisterWithLuaFn pfn) { LuaManager::Register(pfn); }
};
#define REGISTER_WITH_LUA_FUNCTION(Fn)                                         \
	static RegisterLuaFunction register##Fn(Fn);

inline auto
MyLua_checkboolean(lua_State* L, int numArg) -> bool
{
	luaL_checktype(L, numArg, LUA_TBOOLEAN);
	return !(lua_toboolean(L, numArg) == 0);
}

/* BIArg is like BArg, except 1 is accepted as a true value and (as a special
 * case) 0 is accepted as a false value.  This is to help transitions where
 * "cmd,0" is used to mean "cmd,false". */
inline auto
MyLua_checkintboolean(lua_State* L, int iArg) -> bool
{
	luaL_checkany(L, iArg);
	int iType = lua_type(L, iArg);
	if (iType == LUA_TNUMBER) {
		int iValue = static_cast<int>(lua_tointeger(L, iArg));
		return iValue != 0;
	}

	return MyLua_checkboolean(L, iArg);
}

// Checks the table at index to verify that it contains strings.
inline auto
TableContainsOnlyStrings(lua_State* L, int index) -> bool
{
	bool passed = true;
	lua_pushnil(L);
	while (lua_next(L, index) != 0) {
		// `key' is at index -2 and `value' at index -1
		const char* pValue = lua_tostring(L, -1);
		if (pValue == nullptr) {
			// Was going to print an error to the log with the key that failed,
			// but didn't want to pull in RageLog. -Kyz
			passed = false;
		}
		lua_pop(L, 1);
	}
	return passed;
}

auto
GetFuncArg(int n, lua_State* L) -> LuaReference;
#define SArg(n) (luaL_checkstring(L, (n)))
#define BIArg(n) (MyLua_checkintboolean(L, (n)))
#define IArg(n) (luaL_checkint(L, (n)))
#define BArg(n) (MyLua_checkboolean(L, (n)))
#define FArg(n) (static_cast<float>(luaL_checknumber(L, (n))))

// SafeFArg is for places that need to get a number off the lua stack, but
// can't risk an error being raised.  IArg and luaL_optnumber would both raise
// an error on a type mismatch. -Kyz
inline auto
SafeFArg(lua_State* L, int index, std::string const& err, int def) -> int
{
	if (lua_isnumber(L, index) != 0) {
		return static_cast<int>(lua_tonumber(L, index));
	}
	LuaHelpers::ReportScriptError(err);
	return def;
}

inline auto
get_optional_double(lua_State* L, int index, char const* field, double def)
  -> double
{
	double ret = def;
	lua_getfield(L, index, field);
	if (lua_isnumber(L, -1) != 0) {
		ret = static_cast<double>(lua_tonumber(L, -1));
	}
	lua_pop(L, 1);
	return ret;
}

inline auto
get_optional_int(lua_State* L, int index, char const* field, int def) -> int
{
	int ret = def;
	lua_getfield(L, index, field);
	if (lua_isnumber(L, -1) != 0) {
		ret = static_cast<int>(lua_tonumber(L, -1));
	}
	lua_pop(L, 1);
	return ret;
}

inline auto
get_optional_bool(lua_State* L, int index, char const* field) -> bool
{
	lua_getfield(L, index, field);
	bool ret = lua_toboolean(L, -1) == 1;
	lua_pop(L, 1);
	return ret;
}

inline auto
value_is_in_table(lua_State* L, int value_index, int table_index) -> bool
{
	lua_pushnil(L);
	while (lua_next(L, table_index) != 0) {
		if (lua_equal(L, value_index, -1) != 0) {
			lua_pop(L, 2);
			return true;
		}
		lua_pop(L, 1);
	}
	return false;
}

#define LuaFunction(func, expr)                                                \
                                                                               \
	int LuaFunc_##func(lua_State* L);                                          \
                                                                               \
	int LuaFunc_##func(lua_State* L)                                           \
	{                                                                          \
		LuaHelpers::Push(L, expr);                                             \
		return 1;                                                              \
	}                                                                          \
                                                                               \
	void LuaFunc_Register_##func(lua_State* L);                                \
                                                                               \
	void LuaFunc_Register_##func(lua_State* L)                                 \
	{                                                                          \
		lua_register(L, #func, LuaFunc_##func);                                \
	}                                                                          \
                                                                               \
	REGISTER_WITH_LUA_FUNCTION(LuaFunc_Register_##func);

#define LUAFUNC_REGISTER_COMMON(func_name)                                     \
                                                                               \
	void LuaFunc_Register_##func_name(lua_State* L);                           \
                                                                               \
	void LuaFunc_Register_##func_name(lua_State* L)                            \
	{                                                                          \
		lua_register(L, #func_name, LuaFunc_##func_name);                      \
	}                                                                          \
                                                                               \
	REGISTER_WITH_LUA_FUNCTION(LuaFunc_Register_##func_name);

#endif
