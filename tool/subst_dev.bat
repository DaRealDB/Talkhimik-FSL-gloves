@echo off
rem Talkhimik dev-environment helper (Windows).
rem
rem Maps T: to the Thesis workspace and tells you to run Flutter tooling
rem from T:\talkhimik_app instead of the real path.
rem
rem WHY: this machine's user profile path contains a space
rem ("C:\Users\Daryl Bacusmo\..."). cmd.exe mangles `name=value` arguments
rem whose value contains spaces (quotes are dropped at the `=`), which
rem breaks the native-assets hook compilation that `flutter test` /
rem `flutter run` perform for transitive packages such as objective_c and
rem jni ("'C:\Users\Daryl' is not recognized as an internal or external
rem command"). Running the project through a space-free drive alias
rem sidesteps the bug without patching the SDK.
rem
rem Usage (once per logon session):
rem   tool\subst_dev.bat
rem   T:
rem   cd T:\talkhimik_app
rem   flutter test / run / build  (from there)
rem
rem The mapping disappears on reboot; re-run this script after logging in.

subst T: "C:\Users\Daryl Bacusmo\Documents\Thesis"
echo.
echo T: now points to the Thesis workspace.
echo Run your flutter commands from T:\talkhimik_app .
echo.
subst
