-- based on log file
-- SOURCE{"freeswitch",
--   "file:c:/FreeSWITCH/log/freeswitch.log",
--   poll = 30, max_line = 20 * 1024;
-- }

-- based on ESL
SOURCE{"freeswitch",
  "esl:ClueCon@127.0.0.1:8021",
  level = 'WARNING';
}
