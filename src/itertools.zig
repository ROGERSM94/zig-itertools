const std = @import("std");
const testing = std.testing;

pub const YieldResultTag = enum {
    result,
    end,
};

pub fn YieldResult(comptime T: type) type {
    return union(YieldResultTag) {
        result: T,
        end,
    };
}

pub const GeneratorYieldErrorset = error {
    EndOfIteration,
};

/// An implementation of python style generators
pub fn Generator(comptime Yield: type, comptime State: type) type {
    return struct {
        const Self = @This();
        const GeneratorFunction = fn (*State) ?Yield;
        const Result = YieldResult(Yield);
        const Return = Yield;
        const UnderlyingState = State;

        /// The current state of the generator
        state: State,

        /// The function that transforms the state and returns the yield
        generationFunction: fn (*State) ?Yield,

        fn init(initialState: State, function: GeneratorFunction) Self {
            return Self {
                .state = initialState,
                .generationFunction = function,
            };
        }

        fn deinit(self: *Self) void {
            self.state.deinit();
        }

        fn next(self: *Self) Result {
            if (self.generationFunction(&self.state)) |value| {
                return Result {.result = value};
            } else {
                return Result.end;
            }
        }

        fn nextValue(self: *Self) GeneratorYieldErrorset!Yield {
            if (self.generationFunction(&self.state)) |value| {
                return value;
            } else {
                return GeneratorYieldErrorset.EndOfIteration;
            }
        }

        fn nextOptional(self: *Self) ?Yield {
            return self.generationFunction(&self.state);
        }
    };
}

fn returns_five(_: *void) ?i32 {
    return 5;
}

test "A simple generator" {
    const IntGenerator = Generator(i32, void);
    var theGenerator = IntGenerator.init({}, returns_five);

    var counter: i32 = 0;
    while (counter < 100) : (counter += 1) {
        switch (theGenerator.next())  {
            IntGenerator.Result.result =>
                |yield| testing.expect(yield == 5),
            IntGenerator.Result.end => testing.expect(false),
        }
    }
}

test "A simple generator via nextValue" {
    const IntGenerator = Generator(i32, void);
    var theGenerator = IntGenerator.init({}, returns_five);

    var counter: i32 = 0;
    while (counter < 100) : (counter += 1) {
        var nextValue = try theGenerator.nextValue();
        testing.expect(nextValue == 5);
    }
}

fn justReturnsNull(_: *void) ?i32 {
    return null;
}

test "A terminating generator" {
    const IntGenerator = Generator(i32, void);
    var theGenerator = IntGenerator.init({}, justReturnsNull);

    testing.expect(
        theGenerator.next() == IntGenerator.Result.end
    );
}

test "A terminating generator" {
    const IntGenerator = Generator(i32, void);
    var theGenerator = IntGenerator.init({}, justReturnsNull);

    testing.expectError(GeneratorYieldErrorset.EndOfIteration,
        theGenerator.nextValue()
    );
}

const SimpleState = struct {
    cur_value: i32,
    max_value: i32,

    fn next(self: *SimpleState) ?i32 {
        if (self.cur_value < self.max_value) {
            defer self.cur_value += 1;
            return self.cur_value;
        } else {
            return null;
        }
    }
};

test "A generator with state" {
    const SimpleGenerator = Generator(i32,SimpleState);
    var initState = SimpleState {
        .cur_value = 0,
        .max_value = 3,
    };
    var theGenerator =
        SimpleGenerator.init(initState, SimpleState.next);

    switch (theGenerator.next())  {
        SimpleGenerator.Result.result =>
            |yield| testing.expect(yield == 0),
        SimpleGenerator.Result.end => testing.expect(false),
    }

    switch (theGenerator.next())  {
        SimpleGenerator.Result.result =>
            |yield| testing.expect(yield == 1),
        SimpleGenerator.Result.end => testing.expect(false),
    }

    switch (theGenerator.next())  {
        SimpleGenerator.Result.result =>
            |yield| testing.expect(yield == 2),
        SimpleGenerator.Result.end => testing.expect(false),
    }

    testing.expect(
        theGenerator.next() == SimpleGenerator.Result.end
    );
}

fn CounterState(comptime T: type) type {
    return struct {
        const Self = @This();

        current: T,
        step: T,


        fn init(start: T, step: T) Self {
            return Self {
                .current = start,
                .step = step,
            };
        }

        fn next(self: *Self) ?T {
            defer self.current+=self.step;
            return self.current;
        }
    };
}

fn Counter(comptime T: type) type {
    return Generator(T, CounterState(T));
}

/// Creates a generator that returns evenly spaced values starting at
/// `start` and increasing each return by `step`
///
/// For example count(i32, 0, 1) would yield 0, 1, 2, 3, 4, 5, ...
/// and count(i32, 10, 5) would yield 10, 15, 20, ...
///
/// Note that this class will not provide any protection from overflow
/// or underflow
pub fn count(comptime T: type, start: T, step: T) Counter(T) {
    return Counter(T).init(
        CounterState(T).init(start, step),
        CounterState(T).next
    );
}

test "Count no step" {
    var counter = count(u32, 0, 1);

    var cur: i32 = 0;
    while (cur < 100) : (cur += 1) {
        switch (counter.next()) {
            YieldResult(u32).result => |value|
                testing.expect(value == cur),
            else => testing.expect(false),
        }
    }
}

test "Counter with step" {
    var counter = count(u32, 0, 17);

    var cur: i32 = 0;
    while (cur < 100) : (cur += 1) {
        switch (counter.next()) {
            YieldResult(u32).result => |value|
                testing.expect(value == cur*17),
            else => testing.expect(false),
        }
    }
}

fn RepeaterState(comptime T: type) type {
    return struct {
        const Self = @This();
        value: T,

        fn init(val: T) Self {
            return Self {
                .value = val,
            };
        }

        fn next(self: *Self) ?T {
            return self.value;
        }
    };
}

fn Repeater(comptime T: type) type {
    return Generator(T, RepeaterState(T));
}

/// Returns a generator that will infinitely repeast the value `val`
///
/// For example repeat(i32, 7) will yield 7, 7, 7, 7, ...
fn repeat(comptime T: type, val: T) Repeater(T) {
    const repeaterState = RepeaterState(T).init(val);
    return Repeater(T).init(repeaterState, RepeaterState(T).next);
}

test "Repeater" {
    var theGenerator = repeat(i32, 7);

    var cur: i32 = 0;
    while (cur < 100) : (cur += 1) {
        var cur_value = try theGenerator.nextValue();
        testing.expect(cur_value == 7);
    }
}

fn CyclerState(comptime T: type) type {
    return struct {
        const Self = @This();

        data: []const T,
        curIndex: usize,

        fn init(data: []const T) Self {
            return Self {
                .data = data,
                .curIndex = 0,
            };
        }

        fn next(self: *Self) ?T {
            defer self.curIndex += 1;
            return self.data[self.curIndex % self.data.len];
        }
    };
}

fn Cycler(comptime T: type) type {
    return Generator(T, CyclerState(T));
}


/// This function does not take ownership over the passed arraylist
/// for example cycle(u8, "abc") would yield 'a', 'b', 'c', 'a', 'b', 'c'
pub fn cycle(comptime T: type, items: []const T) Cycler(T) {
    std.debug.assert(items.len > 0);
    return Cycler(T).init(
        CyclerState(T).init(items),
        CyclerState(T).next
    );
}

test "Cycle" {
    const cycleItems = [_]i32{1, 2};

    var theGenerator = cycle(i32, cycleItems[0..]);

    var cur: i32 = 0;
    while (cur < 100) : (cur += 1) {
        const firstValue = try theGenerator.nextValue();
        testing.expect(firstValue == 1);
        const secondValue = try theGenerator.nextValue();
        testing.expect(secondValue == 2);
    }
}

test "Cycle with string literal" {
    const cycleItems = "abc";
    var theGenerator = cycle(u8, "abc");
    var cur: i32 = 0;
    while (cur < 100) : (cur += 1) {
        const firstValue = try theGenerator.nextValue();
        testing.expect(firstValue == 'a');
        const secondValue = try theGenerator.nextValue();
        testing.expect(secondValue == 'b');
        const thirdValue = try theGenerator.nextValue();
        testing.expect(thirdValue == 'c');
    }
}

fn AccumulatorState(comptime T: type, comptime GenState: type) type {
    return struct {
        const Self = @This();

        data: Generator(T, GenState),
        accumulatedTotal: ?T,

        /// Initialization can fail due to data being an empty generator
        fn init(data: Generator(T, GenState)) Self {
            return Self {
                .data = data,
                .accumulatedTotal = null,
            };
        }

        fn next(self: *Self) ?T {
            var nextItemToSum = self.data.nextOptional();
            if (nextItemToSum == null)
                return null;

            if (self.accumulatedTotal == null) {
                self.accumulatedTotal = nextItemToSum;
            } else {
                self.accumulatedTotal =
                    self.accumulatedTotal.? + nextItemToSum.?;
            }
            return self.accumulatedTotal;
        }
    };
}

fn Accumulator(comptime T: type, comptime GenState: type) type {
    return Generator(T, AccumulatorState(T, GenState));
}

/// Yields the accumulation of a generator, the only requirement is that
/// T supports operator +, note that this is a more specialized version
/// of a `fold` operation
///
/// example:
///    var generator = repeat(i32, 2);
///    var accumulator = 
///         accumulate(generator.Return, generator.UnderlyingState, generator);
///    2 == try accumulator.nextValue();
///    4 == try accumulator.nextValue();
///    6 == try accumulator.nextValue();
pub fn accumulate(comptime T: type, comptime GenState: type,
                  data: Generator(T, GenState))
                  Accumulator(T, GenState) {
    return Accumulator(T, GenState).init(
        AccumulatorState(T, GenState).init(data),
        AccumulatorState(T, GenState).next
    );
}

test "Accumulator sum 0 to 2" {
    var state = SimpleState {
        .cur_value = 0,
        .max_value = 3,
    };

    var theGenerator =
        Generator(i32, SimpleState).init(state, SimpleState.next);

    var theAccumulator = accumulate(i32, SimpleState, theGenerator);

    var first = try theAccumulator.nextValue();
    testing.expect(first == 0);

    var second = try theAccumulator.nextValue();
    testing.expect(second == 1);

    var third = try theAccumulator.nextValue();
    testing.expect(third == 3);

    var final = theAccumulator.next();
    testing.expect(final == YieldResult(i32).end);
}

