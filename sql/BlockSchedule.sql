-- Temp IDs Table
 CREATE TABLE #TempAdobeUserIdList (id INT);
 INSERT INTO #TempAdobeUserIdList (id) VALUES MY_VALUES;
-- Block Schedule
SELECT DISTINCT STU.ID
FROM   (SELECT [stf].*
FROM   stf
WHERE  del = 0) STF
RIGHT JOIN ((SELECT [sse].*
  FROM   sse
  WHERE  del = 0) SSE
  RIGHT JOIN ((SELECT [mst].*
    FROM   mst
    WHERE  del = 0) MST
    RIGHT JOIN ((SELECT [stu].*
                FROM   stu
                WHERE  del = 0) STU
                LEFT JOIN (SELECT [sec].*
                           FROM   sec
                           WHERE  del = 0) SEC
                       ON [STU].[sc] = [SEC].[sc]
                          AND [STU].[sn] =
               [SEC].[sn])
            ON [MST].[sc] = [SEC].[sc]
               AND [MST].[se] = [SEC].[se])
ON [MST].[sc] = [SSE].[sc]
   AND [MST].[se] = [SSE].[se])
 ON [STF].[id] = [SSE].[id]
WHERE
( NOT STU.tg > ' ' )
-- This SQL will not run natively.
-- {0} and {1} are replaced with Teacher ID and Section number(s).
AND (SSE.ID = @id AND MST.SE IN (SELECT id FROM #TempAdobeUserIdList))
ORDER BY STU.ID