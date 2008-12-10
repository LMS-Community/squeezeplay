// Example for use of GNU gettext.
// Copyright (C) 2003-2004 Free Software Foundation, Inc.
// This file is in the public domain.
//
// Source code of the C# program.

using System; /* String, Console */
using GNU.Gettext; /* GettextResourceManager */
using System.Diagnostics; /* Process */

public class Hello {
  public static void Main (String[] args) {
    #if __MonoCS__
    // Some systems don't set CurrentCulture and CurrentUICulture as specified
    // by LC_ALL. So set it by hand.
    String locale = System.Environment.GetEnvironmentVariable("LC_ALL");
    if (locale == null || locale == "")
      locale = System.Environment.GetEnvironmentVariable("LANG");
    if (!(locale == null || locale == "")) {
      if (locale.IndexOf('.') >= 0)
        locale = locale.Substring(0,locale.IndexOf('.'));
      System.Threading.Thread.CurrentThread.CurrentCulture =
      System.Threading.Thread.CurrentThread.CurrentUICulture =
        new System.Globalization.CultureInfo(locale.Replace('_','-'));
    }
    #endif
    GettextResourceManager catalog =
      new GettextResourceManager("hello-csharp");
    Console.WriteLine(catalog.GetString("Hello, world!"));
    Console.WriteLine(
        String.Format(
            catalog.GetString("This program is running as process number {0}."),
            Process.GetCurrentProcess().Id));
  }
}
