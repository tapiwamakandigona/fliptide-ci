# WorkManager is initialized by AndroidX Startup before MainActivity/Flutter.
# Its Room runtime constructs WorkDatabase_Impl by Class.forName(...).newInstance().
# The shipped 0.3.1/code5 DEX retained the class but removed its no-argument
# constructor; native launch CI34338978110 then failed before the first screen.
# Retain exactly this reflective entry point. Keep R8 and resource shrinking on.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
