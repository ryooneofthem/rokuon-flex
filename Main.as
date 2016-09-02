package 
{
	import be.nascom.flash.net.upload.UploadPostHelper;
	
	import com.adobe.audio.format.WAVWriter;
	
	import flash.display.Bitmap;
	import flash.display.SimpleButton;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.ProgressEvent;
	import flash.events.SampleDataEvent;
	import flash.events.SecurityErrorEvent;
	import flash.external.ExternalInterface;
	import flash.media.Microphone;
	import flash.media.Sound;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.navigateToURL;
	import flash.text.TextField;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	import fr.kikko.lab.ShineMP3Encoder;
	
	/**
	 * ...
	 * @author hbb
	 */
	public class Main extends Sprite 
	{
		private var _mic:Microphone;
		private var _voice:ByteArray;
		private var _mp3Encoder:ShineMP3Encoder;
		
		private var _state:String;
		private var _timer:int;
		private var _desc:String;
		
		[Embed (source="/assest/play.png" )]
		public static const ICON_PLAY:Class;
		[Embed (source="/assest/breack.png" )]
		public static const ICON_PAUSE:Class;
		[Embed (source="/assest/rec.png" )]
		public static const ICON_REC:Class;
		[Embed (source="/assest/fileadd.png" )]
		public static const ICON_SAVE:Class;
		
		public function Main():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		}
		
		private function onAddedToStage(e:Event):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			init();
		}
		public function initJavaScriptGateway():void{
			if(ExternalInterface.available){
				//ExternalInterface.addCallback("alertshow", alertshow);
				//ExternalInterface.addCallback("saveFile", saveMP3);
				ExternalInterface.addCallback("setDesc", setDesc);
			} 
		}
		public function setDesc(str:String):void{
			this._desc = str;
		}
		public function onUploadSuccess():void{
			if(ExternalInterface.available){
				ExternalInterface.call("successUpload");
			}
		}
		public function javascriptAlert(msg:String):void{
			var javascriptFunction:String = "showAlert";
			//var message:String = messageText.text;
			
			if(ExternalInterface.available){
				ExternalInterface.call(javascriptFunction, msg);
			}
		}
		private function initButton():void{
			var icon_play:Bitmap = new ICON_PLAY();
			var icon_rec:Bitmap = new ICON_REC();
			var icon_pause:Bitmap = new ICON_PAUSE();
			var icon_save:Bitmap = new ICON_SAVE();
			
			var button_rec:SimpleButton = new SimpleButton(icon_rec,icon_rec,icon_rec);
			var button_play:SimpleButton = new SimpleButton(icon_play,icon_play,icon_play);
			var button_pause:SimpleButton = new SimpleButton(icon_pause,icon_pause,icon_pause);
			var button_save:SimpleButton = new SimpleButton(icon_save,icon_save,icon_save);
			
			button_rec.hitTestState = button_rec.upState;
			button_play.hitTestState = button_play.upState;
			button_pause.hitTestState = button_pause.upState;
			button_save.hitTestState = button_save.upState;
			
			button_play.addEventListener(MouseEvent.CLICK,
				function():void{
					playSound();	
				}
			);
			button_rec.addEventListener(MouseEvent.CLICK,
				function():void{
					startRecording();
				}
			);
			button_pause.addEventListener(MouseEvent.CLICK,
				function():void{
					stopAndEncodeRecording();
				}
			);
			button_save.addEventListener(MouseEvent.CLICK,
				function():void{
					if(null != _desc){
						saveMP3(_desc);
					}else{
						saveMP3();
					}
				}
			);
			
			button_pause.x += 30;
			button_rec.x += 60;
			button_save.x += 90;
			addChild( button_play );
			addChild( button_rec );
			addChild( button_pause );
			addChild( button_save );
		}
		private function init():void
		{
			initJavaScriptGateway();
			initButton();
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			//stage.stageFocusRect = false;
			
			if (!setupMicrophone()) return;
			
			//stage.addEventListener(KeyboardEvent.KEY_UP, commandHandler);
			
			_state = 'pre-recording';
			
			log('press <key>: <r>ecord');
		}
		
		private function setupMicrophone():Boolean
		{
			_mic = Microphone.getMicrophone();
			if (!_mic) { log('no michrophone!'); return false; }
			
			_mic.rate = 44;
			_mic.setSilenceLevel(0, 1000);
			//_mic.setLoopBack(true);
			_mic.setLoopBack(false);
			_mic.setUseEchoSuppression(true);
			return true;
		}
		
		private function commandHandler(e:KeyboardEvent):void 
		{
			switch(String.fromCharCode(e.charCode))
			{
				case 'r':
					startRecording();
					break;
					
				case 'e':
					stopAndEncodeRecording();
					break;
					
				case 's':
					if(null != _desc){
						saveMP3(_desc);
					}else
						saveMP3();
					break;
			}
		}
		public function saveMP3(desc:String="Create by flash"):void
		{
			if (_state != 'encoded') return;
			
			//javascriptAlert('準備上傳');
			//_mp3Encoder.saveAs();
			var parameters:Object = {'desc':desc};
			uploadFile(Config.UPLOAD_URL,_mp3Encoder.mp3Data,parameters,
				function():void{ 
					//javascriptAlert('upload ok!');
					onUploadSuccess();
				},
				function():void{
					_state = 'pre-recording';
					javascriptAlert('error!');
				}
			)
			_state = 'pre-recording';
		}
		private function onProgress(e:ProgressEvent):void{
			log('uploading...'+e.bytesLoaded+'/'+e.bytesTotal);
			
		}
		public function uploadFile(url:String, data:ByteArray, parameters:Object, onDone:Function=null, onError:Function=null, fileName:String="camix_public.mp3"):void {
			var request:URLRequest=new URLRequest();
			request.url=url;
			request.method=URLRequestMethod.POST;
			request.contentType='multipart/form-data; boundary=' + UploadPostHelper.getBoundary();
			request.data=UploadPostHelper.getPostData(fileName, data,'sound', parameters);
			request.requestHeaders.push(new URLRequestHeader('Cache-Control', 'no-cache'));
			var loader:URLLoader=new URLLoader();
			loader.addEventListener(Event.COMPLETE, onDone);
			loader.addEventListener(ProgressEvent.PROGRESS,onProgress);
			loader.addEventListener(IOErrorEvent.IO_ERROR, onError);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
			//javascriptAlert('上傳');
			loader.load(request);
		}
		private function playSound():void{
			
			if (_state != 'pre-recording' && _state != 'encoded') return;
			_state = 'playing';
			_voice.position = 0;
			var soundOutput:Sound = new Sound();
			soundOutput.addEventListener(SampleDataEvent.SAMPLE_DATA, _playSoundSampleDataHandler);
			
			soundOutput.play().addEventListener(Event.SOUND_COMPLETE,function():void{
				//javascriptAlert("播玩");
				_state = 'encoded';
			});
			
		}
		private function _playSoundSampleDataHandler(e:SampleDataEvent) : void    {            
			if (!_voice.bytesAvailable > 0)   {
				return;
			}
			var i:int = 0;
			var _length:Number;
			while (i < 8192)       {                
				_length = 0;
				if (_voice.bytesAvailable > 0)    {
					_length = _voice.readFloat();
				}
				e.data.writeFloat(_length);
				e.data.writeFloat(_length);
				i++;
			}            
		}
		private function startRecording():void
		{
			if (_state != 'pre-recording' && _state != 'encoded') return;
			
			log('press <key>: stop and <e>ncode recording');
			
			_state = 'pre-encoding';
			_voice = new ByteArray();
			_mic.addEventListener(SampleDataEvent.SAMPLE_DATA, onRecord);
		}
		
		private function stopAndEncodeRecording():void
		{
			if (_state != 'pre-encoding') return;
			
			_state = 'encoding';
			_mic.removeEventListener(SampleDataEvent.SAMPLE_DATA, onRecord);
			
			_voice.position = 0;
			
			log('encode start...synchronous convert to a WAV first');
			
			convertToMP3();
		}
		
		private function convertToMP3():void 
		{
			var wavWrite:WAVWriter = new WAVWriter();
			wavWrite.numOfChannels = 1;
			wavWrite.sampleBitRate = 16;
			wavWrite.samplingRate = 44100;
			
			var wav:ByteArray = new ByteArray();
			
			_timer = getTimer();
			wavWrite.processSamples(wav, _voice, 44100, 1);
			log('convert to a WAV used: ' + (getTimer() - _timer) + 'ms');
			
			wav.position = 0;
			log('WAV size:' + wav.bytesAvailable + ' bytes');
			log('Asynchronous convert to MP3 now');
			
			_timer = getTimer();
			_mp3Encoder = new ShineMP3Encoder( wav );
			_mp3Encoder.addEventListener(Event.COMPLETE, onEncoded);
			_mp3Encoder.addEventListener(ProgressEvent.PROGRESS, onEncoding);
			_mp3Encoder.addEventListener(ErrorEvent.ERROR, onEncodeError);
			_mp3Encoder.start();
		}
		
		private function onEncoded(e:Event):void 
		{
			_state = 'encoded';
			log('encode MP3 complete used: ' + (getTimer() - _timer) + 'ms');
			_mp3Encoder.mp3Data.position = 0;
			log('MP3 size:' + _mp3Encoder.mp3Data.bytesAvailable + ' bytes');
			log('press <key>: <s>ave to MP3 or <r>ecord again');
		}
		
		private function onEncoding(e:ProgressEvent):void 
		{
			log('encoding MP3... ' + Number(e.bytesLoaded / e.bytesTotal * 100).toFixed(2) + '%', true);
		}
		
		private function onEncodeError(e:ErrorEvent):void 
		{
			log('encode MP3 error ' + e.text);
		}
		
		private function onRecord(e:SampleDataEvent):void 
		{
			_voice.writeBytes( e.data );
			
			var str:String = '';
			for (var i:int = _mic.activityLevel; i--;)
			{
				str += '*';
			}
			log('recoding ' + str, true);
		}
		
		private function log(msg:String, updateInPlace:Boolean = false):void
		{
			var txt:TextField = getChildByName('logTxt') as TextField;
			if (txt)
			{
				if (updateInPlace)
				{
					if (txt.text.substr( -1, 1) == '\r')
					{
						txt.text = txt.text.substr( 0, txt.text.lastIndexOf('\r', txt.text.length - 2) );
					}
					txt.appendText('\n' + msg + '\n');
				}
				else
				{
					txt.appendText((txt.text.substr(-1,1) == '\r' ? '' : '\n') + msg);
				}
				txt.scrollV = txt.maxScrollV;
			}
			else
			{
				txt = new TextField();
				txt.name = 'logTxt';
				txt.multiline = true;
				txt.width = 800;
				txt.height = 80;
				//txt.x = txt.y = 10;
				txt.x = 0; 
				txt.y = 40;
				txt.text = msg;
				addChild(txt);
			}
		}
	}
	
}