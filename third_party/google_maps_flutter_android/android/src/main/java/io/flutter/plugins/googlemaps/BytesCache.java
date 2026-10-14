// Thuisradar-patch (niet in de originele plugin). Zie third_party/README.md.

package io.flutter.plugins.googlemaps;

import android.graphics.Bitmap;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.google.android.gms.maps.model.BitmapDescriptor;
import java.util.Arrays;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;

/**
 * Onthoudt de laatst gebruikte marker-afbeeldingen (PNG-bytes) als kant-en-klare {@link
 * BitmapDescriptor}.
 *
 * <p>De plugin stuurt bij elke markerwijziging, ook als enkel de positie verandert, de volledige
 * afbeelding mee en decodeerde die telkens opnieuw (twee keer: builder en marker) op de
 * hoofdthread. Met deze cache kosten dezelfde bytes enkel nog een hash en een vergelijking.
 */
final class BytesCache {
  private BytesCache() {}

  /** Bovengrens voor het geheugen van de bewaarde afbeeldingen. */
  private static final long MAX_BYTES = 24L * 1024 * 1024;

  private static final int MAX_ENTRIES = 96;

  private static long totalBytes = 0;

  private static final LinkedHashMap<Key, Entry> entries = new LinkedHashMap<>(32, 0.75f, true);

  @Nullable
  static synchronized BitmapDescriptor get(@NonNull Key key) {
    Entry entry = entries.get(key);
    return entry == null ? null : entry.descriptor;
  }

  static synchronized void put(
      @NonNull Key key, @NonNull BitmapDescriptor descriptor, @Nullable Bitmap bitmap) {
    long size = bitmap == null ? 0 : bitmap.getAllocationByteCount();
    if (size > MAX_BYTES) {
      return;
    }
    Entry previous = entries.put(key, new Entry(descriptor, size));
    if (previous != null) {
      totalBytes -= previous.size;
    }
    totalBytes += size;
    Iterator<Map.Entry<Key, Entry>> oldest = entries.entrySet().iterator();
    while ((totalBytes > MAX_BYTES || entries.size() > MAX_ENTRIES) && oldest.hasNext()) {
      Map.Entry<Key, Entry> eldest = oldest.next();
      if (eldest.getKey().equals(key)) {
        continue;
      }
      totalBytes -= eldest.getValue().size;
      oldest.remove();
    }
  }

  private static final class Entry {
    final BitmapDescriptor descriptor;
    final long size;

    Entry(BitmapDescriptor descriptor, long size) {
      this.descriptor = descriptor;
      this.size = size;
    }
  }

  /** Inhoud van de afbeelding plus alles wat de schaal van het resultaat bepaalt. */
  static final class Key {
    private final byte[] bytes;
    private final String scaling;
    private final double imagePixelRatio;
    @Nullable private final Double width;
    @Nullable private final Double height;
    private final float density;
    private final int hash;

    Key(@NonNull PlatformBitmapBytesMap bytesMap, float density) {
      this.bytes = bytesMap.getByteData();
      this.scaling = bytesMap.getBitmapScaling().name();
      this.imagePixelRatio = bytesMap.getImagePixelRatio();
      this.width = bytesMap.getWidth();
      this.height = bytesMap.getHeight();
      this.density = density;
      this.hash =
          Objects.hash(Arrays.hashCode(bytes), scaling, imagePixelRatio, width, height, density);
    }

    @Override
    public boolean equals(Object other) {
      if (this == other) {
        return true;
      }
      if (!(other instanceof Key)) {
        return false;
      }
      Key that = (Key) other;
      return hash == that.hash
          && Double.compare(imagePixelRatio, that.imagePixelRatio) == 0
          && Float.compare(density, that.density) == 0
          && scaling.equals(that.scaling)
          && Objects.equals(width, that.width)
          && Objects.equals(height, that.height)
          && Arrays.equals(bytes, that.bytes);
    }

    @Override
    public int hashCode() {
      return hash;
    }
  }
}
