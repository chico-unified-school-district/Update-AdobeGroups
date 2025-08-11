-- Temp IDs Table
 CREATE TABLE #TempAdobeUserIdList (id INT);
 INSERT INTO #TempAdobeUserIdList (id) VALUES MY_VALUES;
-- Regular Schedule
SELECT
	[STU].[ID], [MST].[SE], [TCH].[TE], [TCH].[TN]
FROM
	(SELECT [TCH].* FROM TCH WHERE DEL = 0) TCH
	RIGHT JOIN
	(
	(SELECT [MST].* FROM MST WHERE DEL = 0) MST
	RIGHT JOIN ((SELECT [STU].* FROM STU WHERE DEL = 0) STU
	LEFT JOIN (SELECT [SEC].* FROM SEC WHERE DEL = 0) SEC
	ON [STU].[SC] = [SEC].[SC] AND [STU].[SN] = [SEC].[SN]
	)
	ON [MST].[SC] = [SEC].[SC] AND [MST].[SE] = [SEC].[SE])
	ON [TCH].[SC] = [MST].[SC] AND [TCH].[TN] = [MST].[TN]
WHERE
	(NOT STU.TG > ' ') AND
	-- This SQL will not run natively.
	-- {0} and {1} are replaced with Teacher ID and Section number(s).
	( [TCH].[ID] = @id AND [SEC].[SE] IN (SELECT id FROM #TempAdobeUserIdList))
ORDER BY [STU].[LN], [STU].[FN];