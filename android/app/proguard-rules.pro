# Flutter genel R8/shrink korumaları.
-keep class io.flutter.** { *; }
-keep class com.neredekilacagim.** { *; }
-dontwarn io.flutter.embedding.**

# Harita (flutter_map/latlong2) ve konum (geolocator) eklentileri.
-keep public class org.osmdroid.** { *; }
-dontwarn org.osmdroid.**

# google.gson (isteyen eklenti kullanıyorsa).
-keep class com.google.gson.** { *; }