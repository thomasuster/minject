/*
Copyright (c) 2012-2014 Massive Interactive

Permission is hereby granted, free of charge, to any person obtaining a copy of 
this software and associated documentation files (the "Software"), to deal in 
the Software without restriction, including without limitation the rights to 
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
of the Software, and to permit persons to whom the Software is furnished to do 
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
SOFTWARE.
*/

package minject.result;

import minject.Injector;

class InjectSingletonResult<T> extends InjectionResult
{
	var responseType:Class<T>;
	var response:T;
	
	public function new(responseType:Class<T>)
	{
		super();
		this.responseType = responseType;
	}
	
	override public function getResponse(injector:Injector):T
	{
		if (response == null)
		{
			response = createResponse(injector);
			injector.injectInto(response);
		}

		return response;
	}
	
	function createResponse(injector:Injector):T
	{
		return injector.construct(responseType);
	}

	override public function toString():String
	{
		return "singleton " + Type.getClassName(responseType);
	}
}
