
local projectName = 'Sirin'
local moduleName = 'SirinDatabaseLoaderDemo'

local script = {
	m_strUUID = projectName .. ".lua." .. moduleName,
}

function script.onThreadBegin()
end

function script.onThreadEnd()
end

local function autoInit()
	if not _G[moduleName] then
		_G[moduleName] = script

		table.insert(SirinLua.onThreadBegin, function() _G[moduleName].onThreadBegin() end)
		table.insert(SirinLua.onThreadEnd, function() _G[moduleName].onThreadEnd() end)
	end

	SirinLua.HookMgr.releaseHookByUID(script.m_strUUID)
	SirinLua.HookMgr.releaseHookByUID(script.m_strUUID)
	SirinLua.HookMgr.addHook("checkDatabase", HOOK_POS.filter, script.m_strUUID, script.checkDatabase)
	SirinLua.HookMgr.addHook("SirinWorldDB_PlayerLoad", HOOK_POS.after_event, script.m_strUUID, script.onPlayerLoad)
	SirinLua.HookMgr.addHook("SirinWorldDB_PlayerLogout", HOOK_POS.after_event, script.m_strUUID, script.onPlayerUpdate)
	SirinLua.HookMgr.addHook("SirinWorldDB_PlayerLobby", HOOK_POS.after_event, script.m_strUUID, script.onPlayerUpdate)
	SirinLua.HookMgr.addHook("SirinWorldDB_PlayerUpdate", HOOK_POS.after_event, script.m_strUUID, script.onPlayerUpdate)

end

local SQL = Sirin.worldDBThread.g_WorldDatabaseEx

---This function checks that object already exists in database
---@param strObjName string
---@param strObjType string 'U' - table, 'P' - procedure
---@return boolean
local function isObjectExists(strObjName, strObjType)
	local set = nil
	local sqlRet = SQL_SUCCESS
	local pszQuery = string.format([[IF OBJECT_ID('%s', '%s') is not null
		SELECT 2 AS 'Ret'
		ELSE
		SELECT 1 AS 'Ret';]], strObjName, strObjType)

	repeat
		sqlRet = SQL:SQLExecDirect(pszQuery, SQL_NTS)

		if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
			break
		else
			sqlRet, set = SQL:FetchSelected(4)
		end

	until true

	if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
		SQL:ErrorAction(sqlRet, pszQuery, moduleName .. ": isObjectExists()")
		set = nil
	end

	sqlRet = SQL:SQLFreeStmt(SQL_CLOSE)

	if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
		SQL:ErrorAction(sqlRet, "SQLFreeStmt", moduleName .. ": isObjectExists()")
	end

	if set then
		local l = set:GetList()

		if l and #l > 0 then
			local bSucc, Ret = l[1]:PopInt32()

			if not bSucc then
				Sirin.console.LogEx(ConsoleForeground.RED, ConsoleBackground.BLACK, moduleName .. ": isObjectExists() l[1]:PopInt32() == false\n")
			end

			if bSucc and Ret == 2 then
				return true
			end
		end
	end

	return false
end

---This hook helps add necessary tables and procedures to database
---@return boolean
function script.checkDatabase()
	local bRet = true
	local sqlRet = SQL_SUCCESS

	if not isObjectExists("tbl_custom_table", "U") then
		local pszQuery = [[CREATE TABLE [dbo].[tbl_custom_table](
			[Serial][int] NOT NULL,
			[Data][int] NOT NULL,
			CONSTRAINT [PK_tbl_custom_table] PRIMARY KEY CLUSTERED
			(
				[Serial] ASC
			) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
			) ON [PRIMARY];]]

		sqlRet = SQL:SQLExecDirect(pszQuery, SQL_NTS)

		if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO and sqlRet ~= SQL_NO_DATA then
			SQL:ErrorAction(sqlRet, pszQuery, moduleName .. ": checkDatabase()")
			bRet = false
		end

		sqlRet = SQL:SQLFreeStmt(SQL_CLOSE)

		if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
			SQL:ErrorAction(sqlRet, "SQLFreeStmt", moduleName .. ": checkDatabase()")
			bRet = false
		end
	end

	if not bRet then
		return bRet
	end

	if not isObjectExists("Select_CustomData", "P") then
		local pszQuery = [[CREATE PROCEDURE [dbo].[Select_CustomData]
			@Serial int
			AS
			SELECT Serial, Data
			FROM [dbo].[tbl_custom_table]
			WHERE Serial = @Serial]]

		sqlRet = SQL:SQLExecDirect(pszQuery, SQL_NTS)

		if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO and sqlRet ~= SQL_NO_DATA then
			SQL:ErrorAction(sqlRet, pszQuery, moduleName .. ": checkDatabase()")
			bRet = false
		end

		sqlRet = SQL:SQLFreeStmt(SQL_CLOSE)

		if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
			SQL:ErrorAction(sqlRet, "SQLFreeStmt", moduleName .. ": checkDatabase()")
			bRet = false
		end
	end

	if not bRet then
		return bRet
	end

	if not isObjectExists("Update_CustomData", "P") then
		local pszQuery = [[CREATE PROCEDURE [dbo].[Update_CustomData]
			@Serial int,
			@d int
			AS
			UPDATE [dbo].[tbl_custom_table]
			SET Data = @d
			WHERE Serial = @Serial]]

		sqlRet = SQL:SQLExecDirect(pszQuery, SQL_NTS)

		if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO and sqlRet ~= SQL_NO_DATA then
			SQL:ErrorAction(sqlRet, pszQuery, moduleName .. ": checkDatabase()")
			bRet = false
		end

		sqlRet = SQL:SQLFreeStmt(SQL_CLOSE)

		if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
			SQL:ErrorAction(sqlRet, "SQLFreeStmt", moduleName .. ": checkDatabase()")
			bRet = false
		end
	end

	if not bRet then
		return bRet
	end

	return bRet
end

---This hook handles custom data data you want to load along with base player data when player enters game
---@param dwPlayerSerial integer
---@param dwAccountSerial integer
---@param multiSQLResultSet CMultiSQLResultSet -- here you can store loaded data. it will be available on hook SirinWorldDB_PlayerLoad_Complete in mainThread context.
function script.onPlayerLoad(dwPlayerSerial, dwAccountSerial, multiSQLResultSet)
	local bInsertDefault = false
	local sqlRet = SQL_SUCCESS
	local pszQuery = "{ CALL Select_CustomData ( ? ) }"
	local buf = Sirin.CBinaryData(4) -- allocate buffer to store procedure parameters

	repeat
		buf:PushUInt32(dwPlayerSerial) -- size of UINT32 is 4 bytes
		sqlRet = SQL:SQLBindParam(1, SQL_PARAM_INPUT, SQL_C_SLONG, SQL_INTEGER, 0, 0, buf, 4)
		if sqlRet ~= SQL_SUCCESS then break end

		sqlRet = SQL:SQLExecDirect(pszQuery, SQL_NTS)

		if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
			break
		else
			local _sqlRet, set = SQL:FetchSelected(8) -- allocate buffer to store returned data. we return 2 INTs - Serial and Data. Total size is 8 bytes.

			if _sqlRet == SQL_SUCCESS or _sqlRet == SQL_SUCCESS_WITH_INFO then
				multiSQLResultSet:PushData(1, set) -- 1 is your personal unique identifier so each hook could acces its own data.
			end

			local l = set:GetList()

			if #l == 0 then -- chek we received any data
				bInsertDefault = true -- if no data received we can insert default data later
			end
		end

	until true

	if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
		SQL:ErrorAction(sqlRet, pszQuery, moduleName .. ": onPlayerLoad()")
	end

	sqlRet = SQL:SQLFreeStmt(SQL_CLOSE)

	if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
		SQL:ErrorAction(sqlRet, "SQLFreeStmt", moduleName .. ": onPlayerLoad()")
	end

	if bInsertDefault then
		pszQuery = string.format("INSERT INTO tbl_custom_table(Serial, Data) VALUES(%d, %d)", dwPlayerSerial, 0) -- insert default data.
		sqlRet = SQL:SQLExecDirect(pszQuery, SQL_NTS)

		if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
			SQL:ErrorAction(sqlRet, pszQuery, moduleName .. ": onPlayerLoad()")
		end

		sqlRet = SQL:SQLFreeStmt(SQL_CLOSE)

		if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
			SQL:ErrorAction(sqlRet, "SQLFreeStmt", moduleName .. ": onPlayerLoad()")
		end
	end
end

---This function used to handle periodic player data update
---@param dwPlayerSerial integer
---@param multiBinaryData CMultiBinaryData
function script.onPlayerUpdate(dwPlayerSerial, multiBinaryData)
	local pData = multiBinaryData:GetData(1) -- 1 is you unique identifier to identify particular data across the hooks. This data came from hook SirinWorldDB_PlayerSave_Prepare in mainThread context.

	if pData then
		local AffectedRowNum = 0
		local sqlRet = SQL_SUCCESS
		local pszQuery = "{ CALL Update_CustomData ( ?, ? ) }"

		repeat
			sqlRet = SQL:SQLBindParam(1, SQL_PARAM_INPUT, SQL_C_SLONG, SQL_INTEGER, 0, 0, pData, 4)
			if sqlRet ~= SQL_SUCCESS then break end

			sqlRet = SQL:SQLBindParam(2, SQL_PARAM_INPUT, SQL_C_SLONG, SQL_INTEGER, 0, 0, pData, 4)
			if sqlRet ~= SQL_SUCCESS then break end

			sqlRet = SQL:SQLExecDirect(pszQuery, SQL_NTS)

			if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
				break
			else
				sqlRet, AffectedRowNum = SQL:SQLRowCount()
			end

		until true

		if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
			SQL:ErrorAction(sqlRet, pszQuery, moduleName .. ": onPlayerUpdate() 1")
		end

		sqlRet = SQL:SQLFreeStmt(SQL_CLOSE)

		if sqlRet ~= SQL_SUCCESS and sqlRet ~= SQL_SUCCESS_WITH_INFO then
			SQL:ErrorAction(sqlRet, "SQLFreeStmt", moduleName .. ": onPlayerUpdate() 1")
		end

		if AffectedRowNum ~= 1 then -- check we have updated exactly one row.
			Sirin.console.LogEx(ConsoleForeground.RED, ConsoleBackground.BLACK, string.format("%s: %s(%d) AffectedRowNum ~= 1\n", moduleName, "onPlayerUpdate 1", dwPlayerSerial))
		end
	end
end

autoInit()
