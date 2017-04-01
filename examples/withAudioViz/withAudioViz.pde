import com.hamoid.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.spi.*;

VideoExport videoExport;

String SEP = "|";
float movieFPS = 30;
float frameDuration = 1 / movieFPS;
float movieTime = 0;
BufferedReader reader;

void setup() {
  size(600, 600);

  // Read a sound file and output a txt file
  // with the FFT analysis.
  // It uses Minim, because the standard
  // Sound library did not work in my system.

  // You could comment out this line once you
  // have produced the txt file to speed up
  // experimentation. Otherwise every time you
  // run this program it re-generates the FFT
  // analysis.
  audioToTextFile("jingle.mp3");

  // Open the text file we just created for reading
  reader = createReader("jingle.mp3.txt");

  // Set up the video exporting
  videoExport = new VideoExport(this);
  videoExport.setFrameRate(movieFPS);
  videoExport.setAudioFileName("jingle.mp3");
  videoExport.startMovie();
}
void draw() {
  String line;
  try {
    line = reader.readLine();
  }
  catch (IOException e) {
    e.printStackTrace();
    line = null;
  }
  if (line == null) {
    // Done reading the file.
    // Close the video file.
    videoExport.endMovie();
    exit();
  } else {
    String[] p = split(line, SEP);
    // The first column indicates 
    // the sound time in seconds.
    float soundTime = float(p[0]);

    // Our movie will have 30 frames per second.
    // Our FFT analysis probably produces 
    // 43 rows per second (44100 / fftSize) or 
    // 46.875 rows per second (48000 / fftSize).
    // We have two different data rates: 30fps vs 43rps.
    // How to deal with that? We render frames as
    // long as the movie time is less than the latest
    // data (sound) time. 
    // I added an offset of half frame duration, 
    // but I'm not sure if it's useful nor what 
    // would be the ideal value. Please experiment :)
    while (movieTime < soundTime + frameDuration * 0.5) {
      background(0);
      noStroke();
      // Iterate over all our data points (different
      // audio frequencies. First bass, then hihats)
      for (int i=1; i<p.length; i++) {
        float value = float(p[i]);
        pushMatrix();
        translate(width/2, height/2);
        if(i%2 == 1) {
          // Left channel value
          fill(255, 50, 20);
          rotate(i * 0.05);
          translate(50, 0);
          rect(value * 5, -5, value * 4, 10);
        } else {
          // Right channel value
          fill(20, 100, 250);
          rotate(-i * 0.05);
          translate(50, 0);
          rect(value * 5, -5, value * 4, 10);
        }
        popMatrix();
      }
      videoExport.saveFrame();
      // Manually increment the movie time.
      // In future versions I should add
      // something like videoExport.getTime() instead.
      movieTime += 1 / movieFPS; 
    }
  }
}

// Minim based audio FFT to data text file conversion.
// You can look at the txt file in the data folder
// after running this program to see how it looks like.
void audioToTextFile(String fileName) {
  PrintWriter output;

  Minim minim = new Minim(this);
  output = createWriter(dataPath(fileName + ".txt"));

  AudioSample track = minim.loadSample(fileName, 2048);

  int fftSize = 1024;
  float sampleRate = track.sampleRate();

  float[] fftSamplesL = new float[fftSize];
  float[] fftSamplesR = new float[fftSize];

  float[] samplesL = track.getChannel(AudioSample.LEFT);
  float[] samplesR = track.getChannel(AudioSample.RIGHT);  

  FFT fftL = new FFT(fftSize, sampleRate);
  FFT fftR = new FFT(fftSize, sampleRate);

  fftL.logAverages(22, 3);
  fftR.logAverages(22, 3);

  int totalChunks = (samplesL.length / fftSize) + 1;
  int fftSlices = fftL.avgSize();

  for (int ci = 0; ci < totalChunks; ++ci) {
    int chunkStartIndex = ci * fftSize;   
    int chunkSize = min( samplesL.length - chunkStartIndex, fftSize );

    System.arraycopy( samplesL, chunkStartIndex, fftSamplesL, 0, chunkSize);      
    System.arraycopy( samplesR, chunkStartIndex, fftSamplesR, 0, chunkSize);      
    if ( chunkSize < fftSize ) {
      java.util.Arrays.fill( fftSamplesL, chunkSize, fftSamplesL.length - 1, 0.0 );
      java.util.Arrays.fill( fftSamplesR, chunkSize, fftSamplesR.length - 1, 0.0 );
    }

    fftL.forward( fftSamplesL );
    fftR.forward( fftSamplesL );

    // The format of the saved txt file.
    // The file contains many rows. Each row looks like this:
    // T|L|R|L|R|L|R|... etc
    // where T is the time in seconds
    // Then we alternate left and right channel FFT values
    // The first L and R values in each row are low frequencies (bass)
    // and they go towards high frequency as we advance towards
    // the end of the line.
    StringBuilder msg = new StringBuilder(nf(chunkStartIndex/sampleRate, 0, 3));
    for (int i=0; i<fftSlices; ++i) {
      msg.append(SEP + nf(fftL.getAvg(i), 0, 4));
      msg.append(SEP + nf(fftR.getAvg(i), 0, 4));
    }
    output.println(msg.toString());
  }
  track.close();
  output.flush();
  output.close();
  println("Sound analysis done");
}