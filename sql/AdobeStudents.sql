SELECT DISTINCT STU.ID
 -- STU.ln                               AS [Last Name],
 -- STU.fn                               AS [First Name],
 -- [STU].[id]                           AS [Student ID],
 -- [STU].[gr]                           AS [Grade],
 -- [MST].[sm]                           AS [Semester],
 -- [SSE].[id]                           AS [Staff ID],
 --(( [STF].[ln] + ', ' + [STF].[fn] )) AS [First Name]
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
AND (SSE.ID = ({0}) AND MST.SE IN ({1}))
ORDER BY STU.ID