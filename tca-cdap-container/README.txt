Note:

Although typically Java jar artifacts have SNAPSHOT version as a.b.c-SNAPSHOT, internally CDAP
identifies the application as a.b.c.SNAPSHOT.  Thus, in app_config JSON we must refer to the 
application as a.b.c.SNAPSHOT.  Otherwise we will have artifact not found error"
