// Compiles a dart2wasm-generated main module from `source` which can then
// be instantiated via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm module from `bytes` which is then
// instantiable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredModules` is a JS function that takes an array of module names
  //   matching wasm files produced by the dart2wasm compiler. It also takes a
  //   callback that should be invoked for each loaded module with 2 arguments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDeferredId` is a JS function that takes load ID produced by the
  //   compiler when the `use-load-ids` option is passed. Each load ID maps to
  //   one or more wasm files as specified in the emitted JSON file. It also
  //   takes a callback that should be invoked for each loaded module with 2
  //   arguments: (1) the module name, (2) the loaded module in a format
  //   supported by `WebAssembly.compile` or `WebAssembly.compileStreaming`.
  //   The callback returns a Promise that resolves when the module is
  //   instantiated.
  //   loadDeferredId should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  async instantiate(additionalImports, {loadDeferredModules, loadDeferredId} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            AB: () => new TextDecoder("utf-8", {fatal: false}),
      AC: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      AD: (x0,x1,x2) => new DataView(x0,x1,x2),
      AE: l => new DataView(new ArrayBuffer(l)),
      B: s => printToConsole(s),
      BB: x0 => x0.length,
      BC: Function.prototype.call.bind(DataView.prototype.setInt8),
      BD: (o, p) => o[p],
      BE: x0 => new DecompressionStream(x0),
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: (string, token) => string.split(token),
      CC: Function.prototype.call.bind(DataView.prototype.getInt8),
      CD: x0 => new Array(x0),
      CE: x0 => x0.getWriter(),
      D: Function.prototype.call.bind(String.prototype.indexOf),
      DB: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      DC: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      DD: (x0,x1,x2) => { x0[x1] = x2 },
      DE: (x0,x1) => x0.write(x1),
      E: o => o,
      EB: s => s.toUpperCase(),
      EC: (o, i) => o[i],
      ED: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      EE: x0 => x0.close(),
      F: s => JSON.stringify(s),
      FB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      FC: o => o.length,
      FD: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      FE: x0 => x0.releaseLock(),
      G: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      GB: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      GC: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        if (o instanceof Promise) return 18;
        return 19;
      },
      GD: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      GE: x0 => x0.readable,
      H: x0 => x0.index,
      HB: (handle) => clearInterval(handle),
      HC: (o, p) => o[p],
      HD: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      HE: x0 => x0.writable,
      I: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      IB: (s) => +s,
      IC: x0 => x0.groups,
      ID: o => o instanceof Uint16Array,
      IE: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      J: () => new Error().stack,
      JB: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      JC: x0 => x0.clearMarks(),
      JD: o => o instanceof Int16Array,
      JE: (d, precision) => d.toPrecision(precision),
      K: o => String(o),
      KB: s => s.trim(),
      KC: x0 => x0.clearMeasures(),
      KD: o => o instanceof Uint8ClampedArray,
      KE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      L: o => o === undefined,
      LB: () => typeof dartUseDateNowForTicks !== "undefined",
      LC: (x0,x1) => x0.parse(x1),
      LD: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      LE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      M: (x0,x1) => x0.exec(x1),
      MB: () => Date.now(),
      MC: (x0,x1,x2) => x0.mark(x1,x2),
      MD: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      ME: x0 => x0.start(),
      N: (x0,x1) => { x0.lastIndex = x1 },
      NB: () => 1000 * performance.now(),
      NC: (x0,x1,x2,x3) => x0.measure(x1,x2,x3),
      ND: () => new Array(),
      NE: x0 => x0.close(),
      O: o => o,
      OB: (handle) => clearTimeout(handle),
      OC: () => globalThis.JSON,
      OD: (x0,x1) => new WebSocket(x0,x1),
      OE: (x0,x1) => x0.postMessage(x1),
      P: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      PB: s => new Date(s * 1000).getTimezoneOffset() * 60,
      PC: x0 => x0.clearMarks,
      PD: x0 => x0.reason,
      PE: (x0,x1) => { x0.onmessageerror = x1 },
      Q: o => o instanceof RegExp,
      QB: Date.now,
      QC: x0 => x0.clearMeasures,
      QD: x0 => x0.code,
      QE: x0 => x0.origin,
      R: (string, times) => string.repeat(times),
      RB: x0 => new WeakRef(x0),
      RC: x0 => x0.mark,
      RD: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      RE: (x0,x1) => { x0.onmessage = x1 },
      S: (s, p, i) => s.lastIndexOf(p, i),
      SB: x0 => x0.deref(),
      SC: x0 => x0.measure,
      SD: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      SE: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      T: o => o,
      TB: () => globalThis.WeakRef,
      TC: () => globalThis.performance,
      TD: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      TE: o => Object.keys(o),
      U: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      UB: (o, p) => p in o,
      UC: o => o.byteOffset,
      UD: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      UE: a => a.length,
      V: x0 => x0.dotAll,
      VB: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      VC: o => o.byteLength,
      VD: (o, t) => typeof o === t,
      VE: x0 => x0.action,
      W: x0 => x0.unicode,
      WB: f => f.dartFunction,
      WC: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      WD: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      WE: (o) => {
        const typeofValue = typeof o;
        return (typeofValue === 'object') ||
            typeofValue === 'function';
      },
      X: x0 => x0.ignoreCase,
      XB: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      XC: (map, o, v) => map.set(o, v),
      XD: x0 => x0.readyState,
      XE: x0 => x0.data,
      Y: x0 => x0.multiline,
      YB: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      YC: (map, o) => map.get(o),
      YD: (x0,x1) => { x0.binaryType = x1 },
      YE: o => o instanceof Array,
      Z: Function.prototype.call.bind(Number.prototype.toString),
      ZB: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      ZC: () => new WeakMap(),
      ZD: o => [o],
      ZE: (a, i, v) => a[i] = v,
      a: Function.prototype.call.bind(BigInt.prototype.toString),
      aB: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      aC: s => s.trimRight(),
      aD: (o0, o1) => [o0, o1],
      aE: (a, l) => a.length = l,
      b: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      bB: o => o.buffer,
      bC: (d, digits) => d.toFixed(digits),
      bD: (o0, o1, o2) => [o0, o1, o2],
      bE: (a, i) => a.splice(i, 1)[0],
      c: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      cB: (b, o) => new DataView(b, o),
      cC: x0 => x0.protocol,
      cD: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      cE: (a, s, e) => a.slice(s, e),
      d: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      dB: (b, o, l) => new DataView(b, o, l),
      dC: (x0,x1,x2) => x0.close(x1,x2),
      dD: () => new AbortController(),
      dE: a => a.pop(),
      e: () => Date.now(),
      eB: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      eC: x0 => x0.close(),
      eD: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      eE: (a, s) => a.join(s),
      f: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      fB: Function.prototype.call.bind(DataView.prototype.getFloat64),
      fC: (x0,x1) => x0.send(x1),
      fD: (x0,x1) => globalThis.fetch(x0,x1),
      fE: (a, i) => a.splice(i, 1),
      g: x0 => x0.random(),
      gB: Function.prototype.call.bind(DataView.prototype.setFloat64),
      gC: () => ({}),
      gD: (x0,x1) => x0.get(x1),
      gE: (a, l) => a.length = l,
      h: () => globalThis.Math,
      hB: (t, s) => t.set(s),
      hC: (o, p, v) => o[p] = v,
      hD: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      hE: (a, b) => a == b ? 0 : (a > b ? 1 : -1),
      i: (l, r) => l === r,
      iB: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      iC: () => [],
      iD: (x0,x1) => x0.forEach(x1),
      iE: x0 => x0.ports,
      j: (x0,x1) => x0.error(x1),
      jB: Function.prototype.call.bind(DataView.prototype.setFloat32),
      jC: (a, i) => a.push(i),
      jD: x0 => x0.name,
      jE: (x0,x1) => { x0.onconnect = x1 },
      k: () => globalThis.console,
      kB: Function.prototype.call.bind(DataView.prototype.getFloat32),
      kC: b => !!b,
      kD: x0 => x0.statusText,
      kE: (o, c) => o instanceof c,
      l: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      lB: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      lC: x0 => new Int8Array(x0),
      lD: x0 => x0.url,
      lE: () => globalThis,
      m: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      mB: Function.prototype.call.bind(DataView.prototype.getUint32),
      mC: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      mD: x0 => x0.status,
      mE: () => globalThis.pubHostedUrl,
      n: (x0,x1) => { x0.onmessage = x1 },
      nB: Function.prototype.call.bind(DataView.prototype.setUint32),
      nC: x0 => new Uint8Array(x0),
      nD: x0 => x0.getReader(),
      nE: () => globalThis.sdkLocation,
      o: (a, i) => a[i],
      oB: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      oC: x0 => new Uint8ClampedArray(x0),
      oD: x0 => x0.read(),
      oE: () => globalThis.assetBaseUrl,
      p: (x0,x1) => x0[x1],
      pB: Function.prototype.call.bind(DataView.prototype.setInt32),
      pC: x0 => new Int16Array(x0),
      pD: x0 => x0.value,
      q: (o, p, r) => o.replace(p, () => r),
      qB: Function.prototype.call.bind(DataView.prototype.getInt32),
      qC: x0 => new Uint16Array(x0),
      qD: x0 => x0.done,
      r: (o, p, r) => o.replaceAll(p, () => r),
      rB: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      rC: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      rD: x0 => x0.cancel(),
      s: x0 => x0.pop(),
      sB: Function.prototype.call.bind(DataView.prototype.setUint16),
      sC: x0 => new Int32Array(x0),
      sD: x0 => x0.body,
      t: x0 => x0.flags,
      tB: Function.prototype.call.bind(DataView.prototype.getUint16),
      tC: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      tD: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      u: Function.prototype.call.bind(String.prototype.toLowerCase),
      uB: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      uC: x0 => new Uint32Array(x0),
      uD: x0 => x0.headers,
      v: Object.is,
      vB: Function.prototype.call.bind(DataView.prototype.setInt16),
      vC: x0 => new Float32Array(x0),
      vD: x0 => x0.signal,
      w: (x0,x1) => x0.test(x1),
      wB: Function.prototype.call.bind(DataView.prototype.getInt16),
      wC: x0 => new Float64Array(x0),
      wD: s => s.trimLeft(),
      x: (decoder, codeUnits) => decoder.decode(codeUnits),
      xB: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      xC: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      xD: x0 => x0.abort(),
      y: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      yB: Function.prototype.call.bind(DataView.prototype.setUint8),
      yC: x0 => new ArrayBuffer(x0),
      yD: (x0,x1) => x0.getRandomValues(x1),
      z: () => new TextDecoder("utf-8", {fatal: true}),
      zB: Function.prototype.call.bind(DataView.prototype.getUint8),
      zC: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      zD: () => globalThis.crypto,

    };

    const baseImports = {
      _: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      WebAssembly: {
        JSTag: WebAssembly.JSTag,
      },
      "": new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}
