## Syntax
This is what Lisle looks like.
````
type Rectangle
    rem instance variables
	var width = 0
        height = 0
    rem instance method
    fnc	area(self)
        return self.width * self.height
    rem constructor
    fnc init(self, width, height)
        self.width = width
        self.height = height 

fnc main()
    rem initialize a new Rectangle instance
    var r = Rectangle(20, 10)
    rem return value is 20 * 10 = 200
    return r:area()
````
### Comments
Lisle supports both single line:
````
rem This is a line comment
````
and block comments:
````
rem This
    is
    a
    multi-line
    comment
````