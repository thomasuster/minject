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

package minject;

import minject.RequestHasher;
import haxe.rtti.Meta;
import haxe.ds.WeakMap;
import haxe.ds.ObjectMap;
import minject.point.PropertyInjectionPoint;
import minject.result.InjectClassResult;
import minject.result.InjectOtherRuleResult;
import minject.result.InjectSingletonResult;
import minject.result.InjectValueResult;

/**
	The dependency injector.
**/
#if !macro @:build(minject.Macro.addMetadata()) #end class Injector
{
	/**
		The parent of this injector.
	**/
	public var parentInjector(default, set):Injector;

	var children:Array<Injector>;
	var injectionConfigs:Map<String, InjectionConfig>;

    static var noArgs:Array<Dynamic>;

	public function new()
	{
		injectionConfigs = new Map();
		children = [];
		noArgs = [];
	}

	/**
		When asked for an instance of the class `whenAskedFor` inject the instance `useValue`.

		This is used to register an existing instance with the injector and treat it like a
		Singleton.

		@param whenAskedFor A class or interface
		@param useValue An instance
		@param named An optional name (id)

		@returns A reference to the rule for this injection. To be used with `mapRule`
	**/
	public function mapValue(whenAskedFor:Class<Dynamic>, useValue:Dynamic, ?named:String = ""):Dynamic
	{
		var config = getMapping(whenAskedFor, named);
		config.setResult(new InjectValueResult(useValue));
		return config;
	}

	/**
		When asked for an instance of the class `whenAskedFor` inject a new instance of
		`instantiateClass`.

		This will create a new instance for each injection.

		@param whenAskedFor A class or interface
		@param instantiateClass A class to instantiate
		@param named An optional name (id)

		@returns A reference to the rule for this injection. To be used with `mapRule`
	**/
	public function mapClass(whenAskedFor:Class<Dynamic>, instantiateClass:Class<Dynamic>, ?named:String=""):Dynamic
	{
		var config = getMapping(whenAskedFor, named);
		config.setResult(new InjectClassResult(instantiateClass));
		return config;
	}

	/**
		When asked for an instance of the class `whenAskedFor` inject an instance of `whenAskedFor`.

		This will create an instance on the first injection, but will re-use that instance for
		subsequent injections.

		@param whenAskedFor A class or interface
		@param named An optional name (id)

		@returns A reference to the rule for this injection. To be used with `mapRule`
	**/
	public function mapSingleton(whenAskedFor:Class<Dynamic>, ?named:String="") :Dynamic
	{
		return mapSingletonOf(whenAskedFor, whenAskedFor, named);
	}

	/**
		When asked for an instance of the class `whenAskedFor`
		inject an instance of `useSingletonOf`.

		This will create an instance on the first injection, but will re-use that instance for
		subsequent injections.

		@param whenAskedFor A class or interface
		@param useSingletonOf A class to instantiate
		@param named An optional name (id)

		@returns A reference to the rule for this injection. To be used with `mapRule`
	**/
	public function mapSingletonOf<T>(whenAskedFor:Class<T>, useSingletonOf:Class<T>, ?named:String=""):InjectionConfig
	{
		var config = getMapping(whenAskedFor, named);
		config.setResult(new InjectSingletonResult(useSingletonOf));
		return config;
	}

	/**
		When asked for an instance of the class `whenAskedFor`
		use rule `useRule` to determine the correct injection.

		This will use whatever injection is set by the given injection rule as created using one
		of the other mapping methods.

		@param whenAskedFor A class or interface
		@param useRule The rule to use for the injection
		@param named An optional name (id)

		@returns A reference to the rule for this injection. To be used with `mapRule`
	**/
	public function mapRule(whenAskedFor:Class<Dynamic>, useRule:Dynamic, ?named:String = ""):Dynamic
	{
		var config = getMapping(whenAskedFor, named);
		config.setResult(new InjectOtherRuleResult(useRule));
		return useRule;
	}

	public function getMapping<T>(forClass:Class<T>, ?named:String=""):InjectionConfig
	{
		var requestName:String = RequestHasher.resolveRequest(forClass, named);
		var config = new InjectionConfig(forClass, named);
		setConfig(requestName, config);
		return config;
	}

	function setConfig(requestName:String, v:InjectionConfig):Void
	{
		injectionConfigs.set(requestName, v);
		for (i in 0...children.length)
		{
			var child = children[i];
			if(!child.hasConfig(requestName))
				child.setConfig(requestName, v);
		}
	}

	public function getConfig(requestName:String):InjectionConfig
	{
		return injectionConfigs.get(requestName);
	}

	public function hasConfig(requestName:String):Bool {
		return injectionConfigs.exists(requestName);
	}

	/**
		Perform an injection into an object, satisfying all it's dependencies

		The `Injector` should throw an `Error` if it can't satisfy all dependencies of the injectee.

		@param target The object to inject into - the Injectee
	**/
	public function injectInto(target:Dynamic):Void
	{
		var targetClass = Type.getClass(target);
		var injectionPoints:Array<PropertyInjectionPoint> = getInjectionPoints(targetClass);
		for (i in 0...injectionPoints.length) {
            applyInjection(target, this, injectionPoints[i]);
        }
	}

    public function applyInjection(target:Dynamic, injector:Injector, point:PropertyInjectionPoint):Dynamic
    {
        var config = injector.getConfig(point.requestName);
        #if debug
            if (config == null)
            {
                var targetName = Type.getClassName(Type.getClass(target));
                throw 'Injector is missing a rule to handle injection into property "${point.name}" ' +
                'of object "$targetName". Target dependency: "${point.requestName}"';
            }
        #end
        Reflect.setProperty(target, point.name, config.getResponse(injector));
        return target;
    }

	/**
		Constructs an instance of theClass without satifying its dependencies.
	**/
	public function construct<T>(theClass:Class<T>):T
	{
		var injecteeDescription:Array<PropertyInjectionPoint> = getInjectionPoints(theClass);
		return Type.createInstance(theClass, noArgs);
	}

	/**
		Create an object of the given class, supplying its dependencies as constructor parameters
		if the used DI solution has support for constructor injection

		Adapters for DI solutions that don't support constructor injection should just create a new
		instance and perform setter and/or method injection on that.

		NOTE: This method will always create a new instance. If you need to retrieve an instance
		consider using `getInstance`

		The `Injector` should throw an `Error` if it can't satisfy all dependencies of the injectee.

		@param theClass The class to instantiate
		@returns The created instance
	**/
	public function instantiate<T>(theClass:Class<T>):T
	{
		var instance = construct(theClass);
		injectInto(instance);
		return instance;
	}

	/**
		Remove a rule from the injector

		@param theClass A class or interface
		@param named An optional name (id)
	**/
	public function unmap(theClass:Class<Dynamic>, ?named:String=""):Void
	{
		var mapping = getConfigurationForRequest(theClass, named);
		if (mapping == null)
		{
			throw 'Error while removing an injector mapping: No mapping defined for class ' + RequestHasher.getClassName(theClass) + ', named "' + named + '"';
		}

		mapping.setResult(null);
	}

	/**
		Does a rule exist to satsify such a request?

		@param forClass A class or interface
		@param named An optional name (id)
		@returns Whether such a mapping exists
	**/
	public function hasMapping(forClass:Class<Dynamic>, ?named:String = ''):Bool
	{
		var mapping = getConfigurationForRequest(forClass, named);
		if (mapping == null)
		{
			return false;
		}

		return mapping.hasResponse(this);
	}

	/**
		Create or retrieve an instance of the given class

		@param ofClass The class to retrieve.
		@param named An optional name (id)
		@return An instance
	**/
	public function getInstance<T>(ofClass:Class<T>, ?named:String=""):T
	{
		var mapping = getConfigurationForRequest(ofClass, named);

		if (mapping == null || !mapping.hasResponse(this))
		{
			throw 'Error while getting mapping response: No mapping defined for class ' + RequestHasher.getClassName(ofClass) + ', named "' + named + '"';
		}

		return mapping.getResponse(this);
	}

	/**
		Create an injector that inherits rules from its parent

		@returns The injector
	**/
	public function createChildInjector():Injector
	{
		var child = new Injector();
		child.parentInjector = this;
		return child;
	}

	/**
		Searches for an injection mapping in the ancestry of the injector. This method is called
		when a dependency cannot be satisfied by this injector.
	**/
	public function getAncestorMapping(forClass:Class<Dynamic>, named:String=null):InjectionConfig
	{
		var parent = parentInjector;

		while (parent != null)
		{
			var parentConfig = parent.getConfigurationForRequest(forClass, named);

			if (parentConfig != null && parentConfig.hasOwnResponse())
			{
				return parentConfig;
			}

			parent = parent.parentInjector;
		}

		return null;
	}

	function getInjectionPoints(forClass:Class<Dynamic>):Array<PropertyInjectionPoint>
	{
		#if debug
        var typeMeta = Meta.getType(forClass);
		if (typeMeta != null && Reflect.hasField(typeMeta, "interface"))
			throw "Interfaces can't be used as instantiatable classes.";
		#end

		var fieldsMeta = getFields(forClass);
		var injectionPoints:Array<PropertyInjectionPoint> = [];

		for (field in fieldsMeta.keys())
		{
            var fieldMeta:Dynamic = fieldsMeta.get(field);
            var type = Reflect.field(fieldMeta, "type");
            if(type!= null) {
                var name = fieldMeta.inject == null ? null : fieldMeta.inject[0];
                var typeString:String = fieldMeta.type[0];
                var point:PropertyInjectionPoint = new PropertyInjectionPoint();
                point.name = field;
                point.requestName = RequestHasher.resolveRequestByString(typeString, name);
                injectionPoints.push(point);
            }
		}
        return injectionPoints;
	}

	function getConfigurationForRequest(forClass:Class<Dynamic>, named:String):InjectionConfig
	{
		var requestName:String = RequestHasher.resolveRequest(forClass, named);
		return injectionConfigs.get(requestName);
	}

	function set_parentInjector(value:Injector):Injector
	{
		parentInjector = value;
		parentInjector.children.push(this);
		for (key in parentInjector.injectionConfigs.keys())
			if(!injectionConfigs.exists(key))
				setConfig(key, parentInjector.injectionConfigs.get(key));

		return parentInjector;
	}

	function getFields(type:Class<Dynamic>):Map<String,Dynamic>
	{
		var meta:Map<String,Dynamic> = new Map<String,Dynamic>();
		while (type != null)
		{
			var typeMeta = haxe.rtti.Meta.getFields(type);
            var fields:Array<String> = Reflect.fields(typeMeta);
            for (i in 0...fields.length) {
                var field = fields[i];
                meta.set(field, Reflect.field(typeMeta, field));
            }
			type = Type.getSuperClass(type);
		}
		return meta;
	}
}

/**
	Contains the set of objects which have been injected into.

	Under dynamic languages that don't support weak references this set a
	hidden property on an injectee when added, to mark it as injected. This is
	to avoid storing a direct reference of it here, causing it never to be
	available for GC.
**/
class InjecteeSet
{
	#if (flash9 || java || php)
	var map:WeakMap<{}, Bool>;
	#elseif cpp
	#end

	public function new()
	{
		#if (flash9 || java || php)
		map = new WeakMap<{}, Bool>();
		#elseif cpp
		#end
	}

	public function add(value:Dynamic)
	{
		#if (flash9 || java || php)
		map.set(value, true);
		#elseif cpp
		#else
		value.__injected__ = true;
		#end
	}

	public function contains(value:Dynamic)
	{
		#if (flash9 || java || php)
		return map.exists(value);
		#elseif cpp
        return false;
		#else
		return value.__injected__ == true;
		#end
	}

	public function remove(value:Dynamic)
	{
		#if (flash9 || java || php)
		map.remove(value);
		#elseif cpp
		#else
		Reflect.deleteField(value, "__injected__");
		#end
	}

	// deprecated
	inline public function delete(value:Dynamic) remove(value);

	/**
		Under dynamic targets that don't support weak refs (js, avm1, neko) this will always
		return an empty iterator due to values not being stored in this set. This is to avoid
		memory leaks.
	**/
	public function iterator()
	{
		#if (flash9 || java || php)
		return map.iterator();
		#else
		return [].iterator();
		#end
	}
}
