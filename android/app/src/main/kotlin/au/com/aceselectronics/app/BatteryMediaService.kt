package au.com.aceselectronics.sss

import android.os.Bundle
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.media.MediaBrowserServiceCompat
import androidx.lifecycle.Observer

class BatteryMediaService : MediaBrowserServiceCompat() {

    private lateinit var mediaSession: MediaSessionCompat
    private val dataObserver = Observer<BatteryData> { data ->
        updateMediaSession(data)
    }

    override fun onCreate() {
        super.onCreate()

        // Create a MediaSessionCompat
        mediaSession = MediaSessionCompat(this, "BatteryMediaService")
        sessionToken = mediaSession.sessionToken

        // Set an initial PlaybackState
        val playbackState = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY | PlaybackStateCompat.ACTION_PAUSE
            )
            .setState(PlaybackStateCompat.STATE_PAUSED, PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, 1.0f)
            .build()
        mediaSession.setPlaybackState(playbackState)

        // Observe data changes
        // Since Service is a LifecycleOwner (if using LifecycleService), but MediaBrowserServiceCompat is not by default a LifecycleService.
        // We need to manage observation manually or use observeForever.
        // Because DataHolder is a singleton with LiveData, observeForever is okay if we remove in onDestroy.
        DataHolder.batteryData.observeForever(dataObserver)
        
        mediaSession.isActive = true
    }

    override fun onDestroy() {
        mediaSession.release()
        DataHolder.batteryData.removeObserver(dataObserver)
        super.onDestroy()
    }

    override fun onGetRoot(
        clientPackageName: String,
        clientUid: Int,
        rootHints: Bundle?
    ): BrowserRoot? {
        // Return a root ID to allow connection from Android Auto
        return BrowserRoot("root", null)
    }

    override fun onLoadChildren(
        parentId: String,
        result: Result<List<MediaBrowserCompat.MediaItem>>
    ) {
        // We don't really have a library to browse, just return empty
        result.sendResult(emptyList())
    }

    private fun updateMediaSession(data: BatteryData) {
        // Format strings for display
        // Title: Voltage & Current because they are most important
        // Artist (Subtitle): Power & SOC
        // Album: Time Remaining

        val title = "%.2fV  •  %.2fA".format(data.voltage, data.current)
        val subtitle = "%.0f%%  •  %.0fW".format(data.soc, data.power)
        val description = if (data.timeRemaining.isNotEmpty()) data.timeRemaining else "calculating..."
        
        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, subtitle)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, description)
            // Use a consistent ID
            .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, "battery_status")
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, -1L) // Unknown duration
            .build()

        mediaSession.setMetadata(metadata)
        
        // Ensure state is updated so it shows as 'active' content
        val playbackState = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY | PlaybackStateCompat.ACTION_PAUSE
            )
            .setState(PlaybackStateCompat.STATE_PLAYING, 0L, 0f) // Playing at 0 speed to show as active
            .build()
        mediaSession.setPlaybackState(playbackState)
    }
}
