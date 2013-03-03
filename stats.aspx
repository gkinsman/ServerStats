<%@ Page Language="C#" Debug="true" EnableViewStateMac="false" %>
<%@ Assembly Name="System.Management, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a" %>
<%@ Assembly Name="LINQPad, Version=1.0.0.0, Culture=neutral, PublicKeyToken=21353812cd2a2db5" %>
<%@ Import namespace="System.Management" %>
<%@ Import namespace="System.Diagnostics" %>
<%@ Import namespace="System.IO" %>
<script runat="server">

void Main()
{
  var watch = new Stopwatch();
  watch.Start();

  var exclusions = new List<string> { "system", "local service", "network service"};
  var group = Process.GetProcesses().ToList()
  .Join(GetProcessOwners(),process => process.Id, userMap => userMap.PId,
    (process,userMap) => new {
      userMap.User,
      process.ProcessName,
      process.Id,
      PrivateMemoryMB = ConvertBytesToMegabytes(process.PrivateMemorySize64)})
  .OrderByDescending(joined => joined.PrivateMemoryMB)
  .GroupBy(ordered => ordered.User.ToLower())
  .Where(grouped => !exclusions.Contains(grouped.Key))
  .OrderByDescending(result => result.Sum(y => y.PrivateMemoryMB)).ToList();
  
  var users = group.Select(g => new {User = g.Key, Memory = g.Sum (x => x.PrivateMemoryMB)});

  var writer = LINQPad.Util.CreateXhtmlWriter();
  writer.Write(users);
  writer.Write(group);

  watch.Stop();
  Response.Write(string.Format("Elapsed: {0}.{1}s",watch.Elapsed.Seconds, watch.Elapsed.Milliseconds));
  Response.Write(writer.ToString());
}

public class UserPidMap {
  public string User {get;set;}
  public int PId {get;set;}
}

static IEnumerable<UserPidMap> GetProcessOwners()
{
  string query = "Select * From Win32_Process";
  ManagementObjectSearcher searcher = new ManagementObjectSearcher(query);
  ManagementObjectCollection processList = searcher.Get();
  
  var userMaps = new List<UserPidMap>();

  foreach (ManagementObject obj in processList)
  {
    try {
      var userMap = new UserPidMap();
      string[] argList = new string[] { string.Empty };
      int returnVal = Convert.ToInt32(obj.InvokeMethod("GetOwner", argList));
      if (returnVal == 0) {
        userMap.User = argList[0];
        if(argList[0]== null) continue;
      } else continue;
      userMap.PId = Convert.ToInt32(obj.GetPropertyValue("ProcessId"));
      userMaps.Add(userMap);
    } catch(Exception e) {continue;}
  }
  return userMaps;
}

static double ConvertBytesToMegabytes(long bytes)
{
  return Math.Round((bytes / 1024f) / 1024f);
}

</script>

<html>
<head>
  <title>Current server memory usage</title>
</head>
<body>
      <% Main(); %>
       <br />
</body>
</html>